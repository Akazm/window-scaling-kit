import AppKit
import Atomics
import AXKit
import IOKit.ps
import Mutex

/// A controller that manages window transitions and animations on macOS.
///
/// This class provides functionality to transform window positions and sizes with smooth animations
/// and grid-based snapping. It handles various window transitions including moving, resizing, and
/// screen-to-screen movements.
///
/// The controller supports configurable animation behavior, grid tolerance, and context-aware grid
/// snapping. It uses accessibility APIs to manipulate windows and provides smooth animations
/// with easing functions.
public final class WindowTransitionController: Sendable {

    private let targetFrame: Mutex<CGRect?> = .init(nil)
    private let isResizingTaskRunning = ManagedAtomic<Bool>(false)
    public let config: Mutex<Config>
    
    public init(config: Config = .default) {
        self.config = .init(config)
    }

    private nonisolated func transform(
        window: AXWindow, onScreen screen: NSScreen, withFrame frame: CGRect, transformation: WindowTransition,
        animationDuration duration: TimeInterval?
    ) async throws {
        var absoluteStart: UInt64?
        let startX = frame.origin.x
        let startY = frame.origin.y
        let startWidth = frame.size.width
        let startHeight = frame.size.height
        let invocationsInterval = 1.0 / 240.0
        let timer = Timer.scheduledTimerSequence(withTimeInterval: invocationsInterval, repeats: true)
            .map { _ in
                var timebaseInfo = mach_timebase_info()
                mach_timebase_info(&timebaseInfo)
                return mach_absolute_time() * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
            }
            .pairwise()
        if let duration {
            for try await (start, end) in timer {
                try Task.checkCancellation()
                absoluteStart = if absoluteStart == nil {
                    start
                } else {
                    absoluteStart
                }
                guard
                    let absoluteStart,
                    let targetFrame = self.targetFrame.withLock({ $0 })
                else {
                    continue
                }
                let deltaX = targetFrame.origin.x - startX
                let deltaY = targetFrame.origin.y - startY
                let deltaWidth = targetFrame.size.width - startWidth
                let deltaHeight = targetFrame.size.height - startHeight
                let elapsed = end - absoluteStart
                let elapsedMilliseconds = Double(elapsed) / 1_000_000
                let elapsedSeconds = elapsedMilliseconds / 1000.0
                let progress = easeInOutQuad(min(elapsedSeconds / duration, 1.0))
                let newX = startX + deltaX * progress
                let newY = startY + deltaY * progress
                let newWidth = startWidth + deltaWidth * progress
                let newHeight = startHeight + deltaHeight * progress
                try await MainActor.run {
                    try Task.checkCancellation()
                    try? window.setAttribute(Attribute.size, value: CGSize(width: newWidth, height: newHeight))
                    try? window.setAttribute(Attribute.position, value: CGPoint(x: newX, y: newY))
                }
                if elapsedSeconds >= duration {
                    try Task.checkCancellation()
                    break
                }
            }
        }
        guard let targetFrame = targetFrame.withLock({ $0 }) else {
            return
        }
        var retries = 0
        let maxRetries = 5
        while
            let newFrame = try? window.attribute(.frame, as: CGRect.self),
            retries < maxRetries,
            abs(newFrame.height - targetFrame.height) > 1 || abs(newFrame.width - targetFrame.width) > 1 {
            try? await Task.sleep(seconds: 0.01)
            try Task.checkCancellation()
            try await MainActor.run {
                try Task.checkCancellation()
                try? window.set(size: targetFrame.size)
                try? window.set(position: targetFrame.origin)
            }
            retries += 1
        }
    }

    /// Transforms the focused window according to the provided transition instruction.
    ///
    /// This method handles all types of window transitions including:
    /// - Moving windows (left, right, up, down)
    /// - Resizing windows (from any edge)
    /// - Moving windows between screens
    /// - Grid-based snapping
    ///
    /// The transformation respects the controller's configuration settings for animations
    /// and grid snapping.
    ///
    /// - Parameter inboundInstruction: The transition instruction to apply to the window
    @MainActor
    public func transformRectOfFocusedWindow(withInstruction inboundInstruction: WindowTransition) async {
        guard
            let window = try? AXWindow.focusedWindow(),
            let screen = NSScreen.activeScreen
        else {
            return
        }
        let config = config.withLock { $0 }
        let enableContextAwareGrid = config.enableContextAwareGrid
        let gridTolerance = Proportion.percentual(config.gridTolerance)
        let shouldDisableAnimations = config.disableAnimations
        let initialFrame = targetFrame.withLock { $0 } ?? (try? window.getFrame()) ?? .zero
        let instruction: WindowTransition = switch inboundInstruction {
            case _ where !enableContextAwareGrid:
                inboundInstruction
            case let .moveLeft(breakpoints):
                .moveLeft(breakpoints.merge(with: screen.visibleEdges(on: .horizontal)).with(tolerance: gridTolerance))
            case let .moveRight(breakpoints):
                .moveRight(breakpoints.merge(with: screen.visibleEdges(on: .horizontal)).with(tolerance: gridTolerance))
            case let .moveUp(breakpoints):
                .moveUp(breakpoints.merge(with: screen.visibleEdges(on: .vertical)).with(tolerance: gridTolerance))
            case let .moveDown(breakpoints):
                .moveDown(breakpoints.merge(with: screen.visibleEdges(on: .vertical)).with(tolerance: gridTolerance))
            case let .resizeLeft(increaseOrDecrease, breakpoints):
                .resizeLeft(
                    increaseOrDecrease,
                    breakpoints.merge(with: screen.visibleEdges(on: .horizontal)).with(tolerance: gridTolerance)
                )
            case let .resizeRight(increaseOrDecrease, breakpoints):
                .resizeRight(
                    increaseOrDecrease,
                    breakpoints.merge(with: screen.visibleEdges(on: .horizontal)).with(tolerance: gridTolerance)
                )
            case let .resizeTop(increaseOrDecrease, breakpoints):
                .resizeTop(
                    increaseOrDecrease,
                    breakpoints.merge(with: screen.visibleEdges(on: .vertical)).with(tolerance: gridTolerance)
                )
            case let .resizeBottom(increaseOrDecrease, breakpoints):
                .resizeBottom(
                    increaseOrDecrease,
                    breakpoints.merge(with: screen.visibleEdges(on: .vertical)).with(tolerance: gridTolerance)
                )
            default:
                inboundInstruction
        }
        guard
            let newTargetFrame = instruction.rect(onScreen: screen, from: initialFrame),
            newTargetFrame != initialFrame
        else {
            return
        }
        targetFrame.withLock { $0 = newTargetFrame }
        if isResizingTaskRunning.load(ordering: .sequentiallyConsistent) {
            return
        }
        Task { [weak self] in
            guard let self else {
                return
            }
            isResizingTaskRunning.store(true, ordering: .relaxed)
            /// THX to Rectangle for pointing this out:
            /// https://github.com/rxhanson/Rectangle/blob/master/Rectangle/AccessibilityElement.swift
            let isEnhancedUserInterfaceEnabled = window.application?.isEnhancedUserInterfaceEnabled() ?? false
            if window.application != nil, isEnhancedUserInterfaceEnabled {
                try? window.application?.setAttribute(.enhancedUserInterface, value: kCFBooleanFalse as CFBoolean)
            }
            try? await transform(
                window: window,
                onScreen: screen,
                withFrame: initialFrame,
                transformation: instruction,
                animationDuration: shouldDisableAnimations.evaluateAnimationDuration()
            )
            targetFrame.withLock { $0 = nil }
            if window.application != nil, isEnhancedUserInterfaceEnabled {
                await MainActor.run {
                    try? window.application?.setAttribute(.enhancedUserInterface, value: kCFBooleanFalse as CFBoolean)
                }
            }
            isResizingTaskRunning.store(false, ordering: .relaxed)
        }
    }

}

public extension WindowTransitionController {
    
    /// Configuration options for the WindowTransitionController.
    ///
    /// This struct allows customization of the controller's behavior including grid tolerance,
    /// animation settings, and context-aware grid snapping.
    struct Config: Sendable, Hashable {
        
        /// Controls when window animations should be disabled.
        ///
        /// - `whenOnBattery`: Disables animations when the device is running on battery power
        /// - `enabled`: Always enables animations
        /// - `disabled`: Always disables animations
        /// - `auto`: Automatically determines whether to disable animations based on system settings
        public enum DisableAnimation: Sendable, Hashable {
            case whenOnBattery(TimeInterval)
            case enabled(TimeInterval)
            case disabled
            case auto(TimeInterval)
        }
        
        /// The tolerance value for grid snapping, represented as a decimal between 0 and 1.
        /// A higher value means windows will snap to grid positions more easily.
        public let gridTolerance: Decimal
        
        /// Controls when window animations should be disabled.
        public let disableAnimations: DisableAnimation
        
        /// When enabled, the grid snapping will take into account the visible edges of the screen
        /// and other contextual information for more intelligent window positioning.
        public let enableContextAwareGrid: Bool
        
        /// Creates a new configuration with the specified parameters.
        ///
        /// - Parameters:
        ///   - gridTolerance: The tolerance value for grid snapping (0-1)
        ///   - disableAnimations: When to disable window animations
        ///   - enableContextAwareGrid: Whether to enable context-aware grid snapping
        public init(
            gridTolerance: Decimal,
            disableAnimations: DisableAnimation,
            enableContextAwareGrid: Bool
        ) {
            self.gridTolerance = gridTolerance
            self.disableAnimations = disableAnimations
            self.enableContextAwareGrid = enableContextAwareGrid
        }
        
        /// The default configuration with reasonable values for most use cases.
        public static let `default`: Self = .init(
            gridTolerance: 0.2,
            disableAnimations: .auto(0.1163),
            enableContextAwareGrid: true
        )
    }
}

public extension WindowTransitionController.Config.DisableAnimation {
    
    static func isRunningOnBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
               let powerSource = info[kIOPSPowerSourceStateKey] as? String {
                return powerSource == kIOPSBatteryPowerValue
            }
        }

        return false
    }
    
    func evaluateAnimationDuration() -> TimeInterval? {
        switch self {
            case .enabled(let timeInterval):
                timeInterval
            case .whenOnBattery(let timeInterval):
                Self.isRunningOnBattery() ? nil : timeInterval
            case .disabled:
                nil
            case .auto(let timeInterval):
                Self.isRunningOnBattery() || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    ? nil
                    : timeInterval
        }
    }
    
}

private func easeInOutQuad(_ t: CGFloat) -> CGFloat {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}

private extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
