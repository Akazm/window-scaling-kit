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
    private struct State {
        var targetFrame: CGRect?
        var nextTransitionFrame: CGRect?
    }
    
    private let state: Mutex<State> = .init(.init())
    private let transitionQueue: Mutex<[WindowTransition]> = .init([])
    private let isProcessingTransitions = ManagedAtomic<Bool>(false)
    public let config: Mutex<Config>
    
    public init(config: Config = .default) {
        self.config = .init(config)
    }

    private nonisolated func transform(
        window: AXWindow,
        withFrame frame: CGRect,
        animationDuration duration: TimeInterval?
    ) async throws {
        // Compute target frame upfront to avoid sending screen across actor boundaries
        guard let targetFrame = state.withLock({ $0.targetFrame }) else {
            return
        }
        guard let duration = duration else {
            try await MainActor.run {
                try Task.checkCancellation()
                try? window.setAttribute(Attribute.size, value: targetFrame.size)
                try? window.setAttribute(Attribute.position, value: targetFrame.origin)
            }
            return
        }
        let startTime = CACurrentMediaTime()
        while true {
            try Task.checkCancellation()
            let elapsedSeconds = CACurrentMediaTime() - startTime
            let progress = min(elapsedSeconds / duration, 1.0)
            let easedProgress = easeInOutCubic(progress)
            let newX = frame.origin.x + (targetFrame.origin.x - frame.origin.x) * easedProgress
            let newY = frame.origin.y + (targetFrame.origin.y - frame.origin.y) * easedProgress
            let newWidth = frame.width + (targetFrame.width - frame.width) * easedProgress
            let newHeight = frame.height + (targetFrame.height - frame.height) * easedProgress
            state.withLock { $0.nextTransitionFrame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight) }
            try await MainActor.run {
                try Task.checkCancellation()
                try? window.setAttribute(Attribute.size, value: CGSize(width: newWidth, height: newHeight))
                try? window.setAttribute(Attribute.position, value: CGPoint(x: newX, y: newY))
            }
            if progress >= 1.0 {
                break
            }
            try await Task.sleep(seconds: 1.0 / 120.0)
        }
        // Ensure we reach the final position
        try await MainActor.run {
            try Task.checkCancellation()
            try? window.setAttribute(Attribute.size, value: targetFrame.size)
            try? window.setAttribute(Attribute.position, value: targetFrame.origin)
        }
    }
    
    /// Cancels any scheduled, animated transitions
    public func cancel() {
        transitionQueue.withLock { queue in
            queue.removeAll()
        }
    }
    
    private func clearTransitionState() {
        state.withLock { state in
            state.targetFrame = nil
            state.nextTransitionFrame = nil
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
    /// - Parameter window: The window with the frame to transition
    /// - Parameter transition: The transition instruction to apply to the window
    public func transformRect(ofWindow window: AXWindow, withTransition transition: WindowTransition) async {
        // Add the new transition to the queue
        transitionQueue.withLock { queue in
            queue.append(transition)
        }
        guard !isProcessingTransitions.load(ordering: .sequentiallyConsistent) else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            isProcessingTransitions.store(true, ordering: .relaxed)
            defer {
                clearTransitionState()
                isProcessingTransitions.store(false, ordering: .relaxed)
            }
            while let nextTransition = transitionQueue.withLock({ queue in
                guard !queue.isEmpty else { return nil as WindowTransition? }
                return queue.removeFirst()
            }) {
                guard let screen = NSScreen.activeScreen else {
                    continue
                }
                let config = config.withLock { $0 }
                let enableContextAwareGrid = config.enableContextAwareGrid
                let gridTolerance = Proportion.percentual(config.gridTolerance)
                let shouldDisableAnimations = config.disableAnimations
                let initialFrame = state.withLock { state in
                    state.nextTransitionFrame ?? state.targetFrame ?? (try? window.getFrame()) ?? .zero
                }
                let instruction: WindowTransition = switch nextTransition {
                    case _ where !enableContextAwareGrid:
                        nextTransition
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
                        nextTransition
                }
                
                guard
                    let newTargetFrame = instruction.rect(onScreen: screen, from: initialFrame),
                    newTargetFrame != initialFrame
                else {
                    continue
                }
                state.withLock { $0.targetFrame = newTargetFrame }
                try? await transform(
                    window: window,
                    withFrame: initialFrame,
                    animationDuration: shouldDisableAnimations.evaluateAnimationDuration()
                )
            }
        }
    }
}

/// macOS's standard ease-in-out cubic bezier curve animation.
/// This matches the system's window management animations.
private func easeInOutCubic(_ t: Double) -> Double {
    if t < 0.5 {
        return 4 * t * t * t
    } else {
        let f = t - 1
        return 1 + 4 * f * f * f
    }
}

private extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
