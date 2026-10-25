import AppKit
import Foundation

private extension Decimal {
    func rounded() -> Self {
        rounded(scale: 4, roundingMode: .bankers)
    }
}

// swiftlint disable:identifer_name
/// Proportional representation of window coordinates. Each property represents a value between 0% and 100% of height/width
/// of an arbitrary [NSScreen](https://developer.apple.com/documentation/appkit/nsscreen).
public struct WindowCoordinates: Sendable, Hashable, Codable {
    /// Distance to the left edge
    public let x: Proportion
    /// Distance to the top edge
    public let y: Proportion
    /// Width
    public let w: Proportion
    /// Height
    public let h: Proportion

    /// Initialize with `.fractional` values
    public init(x: Decimal, y: Decimal, w: Decimal, h: Decimal) {
        self.x = .fractional(x)
        self.y = .fractional(y)
        self.w = .fractional(w)
        self.h = .fractional(h)
    }
    
    /// Initialize with either `.fraction` or `.percentual`
    public init(x: Proportion, y: Proportion, w: Proportion, h: Proportion) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// Initializes a fractional represesentation of the `windowFrame`s coordinates on the `screen`
    public init<Screen: WindowContainer>(
        ofWindowFrame windowFrame: CGRect,
        onScreen screen: Screen
    ) where Screen.This == Screen {
        let upperScreenEdge = screen.axVisibleFrame.minY.decimal

        let dockOnLeft  = screen.frame.origin.x.decimal != screen.visibleFrame.origin.x.decimal
        let dockOnRight = screen.frame.maxX.decimal != screen.visibleFrame.maxX.decimal

        let windowWidth  = windowFrame.width.decimal
        let windowHeight = windowFrame.height.decimal

        let availableWidth: Decimal
        let horizontalOffset: Decimal
        if dockOnLeft {
            availableWidth   = screen.visibleFrame.width.decimal
            horizontalOffset = windowFrame.origin.x.decimal - screen.visibleFrame.origin.x.decimal
        } else {
            availableWidth = dockOnRight ? screen.visibleFrame.width.decimal : screen.frame.width.decimal
            horizontalOffset = windowFrame.origin.x.decimal - screen.frame.origin.x.decimal
        }

        let availableHeight = screen.visibleFrame.height.decimal
        let verticalOffset: Decimal = windowFrame.origin.y.decimal - upperScreenEdge
        // A frame reaching past the left or upper edge, say into the menu bar, starts at the edge
        let newValue: WindowCoordinates = .init(
            x: min(1.0, max(0, horizontalOffset / availableWidth).rounded()),
            y: min(1.0, max(0, verticalOffset / availableHeight).rounded()),
            w: min(1.0, abs(windowWidth / availableWidth).rounded()),
            h: min(1.0, abs(windowHeight / availableHeight).rounded())
        )
        self = newValue
    }

    /// Returns a new `CGRect` with an absolute representation of this matrix on the given `screen`. Using Accessibility APIs, it's `origin` and `size`
    /// may be applied to any window to reposition and resize it's frame.
    public func rect<Screen: WindowContainer>(
        forScreen screen: Screen
    ) -> CGRect where Screen.This == Screen {
        let screenRect = screen.axVisibleFrame
        // Each edge is rounded on its own, rather than origin and size, so that the edge a resize keeps stays exactly
        // where it was instead of drifting a point at a time
        let left = (screenRect.size.width * CGFloat(x.fraction)).rounded(.toNearestOrAwayFromZero)
        let right = (screenRect.size.width * CGFloat(maxX.fraction)).rounded(.toNearestOrAwayFromZero)
        let top = (screenRect.size.height * CGFloat(y.fraction)).rounded(.toNearestOrAwayFromZero)
        // Ensure the frame does not exceed the bottom of `screen` or the dock's upper edge
        let bottom = min(
            (screenRect.size.height * CGFloat(maxY.fraction)).rounded(.toNearestOrAwayFromZero),
            screenRect.size.height
        )
        return CGRect(
            x: screenRect.origin.x + left,
            y: screenRect.origin.y + top,
            width: right - left,
            height: bottom - top
        )
    }
    
    /// The maximum X position (`x + w`), representing the right edge of the window in fractional units.
    public var maxX: Proportion {
        w + x
    }
    
    /// The maximum Y position (`y + h`), representing the bottom edge of the window in fractional units.
    public var maxY: Proportion {
        h + y
    }

    public static func round(_ value: Decimal) -> Decimal {
        value.rounded()
    }
}

extension WindowCoordinates: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(String(describing: Self.self))(x: \(x.percentage)%, y: \(y.percentage)%, w: \(w.percentage)%, h: \(h.percentage)%)"
    }
}

// swiftlint enable:identifer_name
