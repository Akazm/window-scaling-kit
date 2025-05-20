import Foundation
import AppKit

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
