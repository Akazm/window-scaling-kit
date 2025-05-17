import Foundation

/// An enumeration that defines how a resize operation should behave.
///
/// This type is used to specify whether a window should grow or shrink during resize operations.
/// It's commonly used in conjunction with `WindowTransition` to determine the direction of
/// window resizing.
public enum ResizeBehavior: String, Sendable, Codable {
    
    /// Indicates that the target should grow in size.
    ///
    /// When used in a resize operation, this will cause the window to increase in size
    /// in the specified direction.
    case grow
    
    /// Indicates that the target should shrink in size.
    ///
    /// When used in a resize operation, this will cause the window to decrease in size
    /// in the specified direction.
    case shrink
    
    /// Returns the opposite resize behavior.
    ///
    /// This is useful when you need to invert the resize direction, for example when
    /// resizing from the opposite edge of a window.
    ///
    /// - Returns: `.shrink` if the behavior is `.grow`, and `.grow` if the behavior is `.shrink`.
    public var inverted: ResizeBehavior {
        switch self {
            case .grow:
                return .shrink
            case .shrink:
                return .grow
        }
    }
}