import CoreGraphics
import SwiftUI

public enum FrameOrVisibleFrame: Sendable {
    case visibleFrame
    case frame
}

public extension WindowContainer where This == Self {
    /// Screen with origin (0,0)
    static var primary: This? {
        screens.first {
            $0.frame.origin.y == 0 && $0.frame.origin.x == 0
        }
    }

    static func screenContaining(point: NSPoint) -> This? {
        screens.first {
            NSMouseInRect(point, $0.frame, false)
        }
    }

    static func screenContaining(rect: CGRect) -> This? {
        var largestPercentageOfRectWithinFrameOfScreen: CGFloat = 0
        var result = Self.main
        for screen in Self.screens {
            let normalizedRect = screen.align(rect: rect)
            if screen.frame.contains(normalizedRect) {
                result = screen
                break
            }
            let percentageOfRectInScreen = screen.percentageOf(rect: normalizedRect)
            if percentageOfRectInScreen > largestPercentageOfRectWithinFrameOfScreen {
                largestPercentageOfRectWithinFrameOfScreen = percentageOfRectInScreen
                result = screen
            }
        }
        return result
    }

    /// Adjusts the given `rect` to align with the coordinate system of the screen's frame or visible frame.
    /// - Parameters:
    ///   - rect: The rectangle to be normalized.
    ///   - frame: Specifies whether to use the screen's full frame or visible frame for normalization.
    /// - Returns: A new rectangle with the `y`-coordinate adjusted to match the screen's coordinate system.
    ///
    /// This is particularly useful for converting between view-related and screen-related coordinate systems
    /// on macOS, where the origin differs between these systems.
    func align(rect: CGRect, in frame: FrameOrVisibleFrame = .frame) -> CGRect {
        var outRect = rect
        let primaryFrame = switch frame {
            case .frame:
                Self.screens[0].frame
            case .visibleFrame:
                Self.screens[0].visibleFrame
        }
        let ownFrame = switch frame {
            case .frame:
                self.frame
            case .visibleFrame:
                visibleFrame
        }
        outRect.origin.y = ownFrame.size.height
            - rect.maxY
            + (primaryFrame.size.height - ownFrame.size.height)
        return outRect
    }

    /// Converts a screen-aligned `rect` back to a view-relative coordinate system.
    /// This is the inverse of `align(rect:in:)`.
    /// - Parameters:
    ///   - rect: The rectangle in screen coordinates.
    ///   - frame: Whether the original alignment was done using the full frame or visible frame.
    /// - Returns: A new rectangle with the `y`-coordinate restored to its original value.
    func unalign(rect: CGRect, from frame: FrameOrVisibleFrame = .frame) -> CGRect {
        var outRect = rect
        let primaryFrame = switch frame {
            case .frame:
                Self.screens[0].frame
            case .visibleFrame:
                Self.screens[0].visibleFrame
        }
        let ownFrame = switch frame {
            case .frame:
                self.frame
            case .visibleFrame:
                visibleFrame
        }
        outRect.origin.y = ownFrame.size.height
            - (rect.origin.y
                + rect.size.height)
            + (primaryFrame.size.height - ownFrame.size.height)
        return outRect
    }

    private func percentageOf(rect: CGRect) -> CGFloat {
        let intersection = frame.intersection(rect)
        var result: CGFloat = 0.0
        if !intersection.isNull {
            result = (intersection.width * intersection.height) / (rect.width * rect.height)
        }
        return result
    }
}
