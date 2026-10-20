import Foundation
import AppKit

public extension WindowTransitionController {

    /// Configuration options for the WindowTransitionController.
    ///
    /// This struct allows customization of the controller's behavior including grid tolerance,
    /// animation settings, and context-aware grid snapping.
    struct Config: Sendable, Hashable, Codable {

        /// Controls when window animations should be disabled, and the ``Spring`` driving them otherwise.
        /// - `enabled`: Always enables animations
        /// - `disabled`: Always disables animations
        /// - `auto`: Automatically determines whether to disable animations based on system settings
        public enum DisableAnimation: Sendable, Hashable, Codable {
            /// Disables animations when the device is running on battery power, animates with the provided `Spring` otherwise
            case whenOnBattery(Spring)
            /// Always animates with the provided `Spring`
            case enabled(Spring)
            /// Disables animations
            case disabled
            /// Disables animations when the device is running on battery power or 'Reduce motion' is enabled in System Settings, animates
            /// with the provided `Spring` otherwise
            case auto(Spring)
        }

        /// Controls when windows should also snap to edges of other visible windows
        public enum EnableContextAwareGrid: Sendable, Hashable, Codable {
            /// Enables context aware snapping
            case enabled
            /// Disables context aware snapping
            case disabled
            /// Disables context aware snapping when *consecutive* transitions (*rapidly*, with a negligible short delay) are applied
            case whenNonConsecutive
        }

        /// The tolerance value for grid snapping, represented as a decimal between 0 and 1.
        /// A higher value means windows will snap to grid positions more easily.
        public var gridTolerance: Decimal

        /// Controls when window animations should be disabled.
        public var disableAnimations: DisableAnimation

        /// When enabled, the grid snapping will take into account the visible edges of the screen
        /// and other contextual information for more intelligent window positioning.
        public var enableContextAwareGrid: EnableContextAwareGrid

        /// Creates a new configuration with the specified parameters.
        ///
        /// - Parameters:
        ///   - gridTolerance: The tolerance value for grid snapping
        ///   - disableAnimations: When to disable window animations
        ///   - enableContextAwareGrid: Whether to enable context-aware grid snapping
        public init(
            gridTolerance: Decimal,
            disableAnimations: DisableAnimation,
            enableContextAwareGrid: EnableContextAwareGrid
        ) {
            self.gridTolerance = gridTolerance
            self.disableAnimations = disableAnimations
            self.enableContextAwareGrid = enableContextAwareGrid
        }

        /// The default configuration with reasonable values for most use cases.
        public static let `default`: Self = .init(
            gridTolerance: 0.2,
            disableAnimations: .auto(.default),
            enableContextAwareGrid: .whenNonConsecutive
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

    /// The spring to animate with, or `nil` when transitions are to be applied instantly.
    func evaluateSpring() -> WindowTransitionController.Config.Spring? {
        switch self {
            case .enabled(let spring):
                spring
            case .whenOnBattery(let spring):
                Self.isRunningOnBattery() ? nil : spring
            case .disabled:
                nil
            case .auto(let spring):
                Self.isRunningOnBattery() || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    ? nil
                    : spring
        }
    }

    @available(*, deprecated, renamed: "evaluateSpring()")
    func evaluateAnimationDuration() -> TimeInterval? {
        evaluateSpring()?.duration
    }

}
