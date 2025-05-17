/// A bitmask option set that represents the axis or axes (horizontal, vertical)
/// along which a window-related operation (e.g., resizing or snapping) applies.
///
/// This type is used throughout the WindowScalingKit to specify which dimensions
/// of a window should be affected by operations like resizing, moving, or snapping.
/// It supports both single-axis and multi-axis operations through bitwise combinations.
///
/// Example usage:
/// ```swift
/// let verticalAxis = WindowAxis.vertical
/// let horizontalAxis = WindowAxis.horizontal
/// let bothAxes = [.horizontal, .vertical]
/// ```
public struct WindowAxis: Sendable, Hashable, OptionSet, Codable {
    /// The raw bitmask value representing the axis configuration.
    public let rawValue: UInt8

    /// Creates a new axis configuration from a raw bitmask value.
    ///
    /// - Parameter rawValue: The raw bitmask value representing the axis configuration.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    /// The vertical axis (e.g., y-coordinate or height).
    ///
    /// This represents operations that affect the window's vertical position or size.
    public static let vertical: Self = WindowAxis(rawValue: 1 << 0)
    /// The horizontal axis (e.g., x-coordinate or width).
    ///
    /// This represents operations that affect the window's horizontal position or size.
    public static let horizontal: Self = WindowAxis(rawValue: 1 << 1)
}
