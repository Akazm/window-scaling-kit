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
        let primaryFrame = Screen.primary?.frame ?? .zero
        let upperScreenEdge = primaryFrame.height.decimal
            - screen.frame.height.decimal
            - screen.frame.origin.y.decimal
            + screen.menuBarThickness.decimal
        let dockWidth = screen.frame.width.decimal - screen.visibleFrame.width.decimal
        let upperWindowEdge = upperScreenEdge - windowFrame.origin.y.decimal
        let isDockOnTheLeft = screen.frame.origin.x.decimal != screen.visibleFrame.origin.x.decimal
        let xDelta = isDockOnTheLeft ? dockWidth : 0.0
        let screenOriginX = screen.frame.origin.x.decimal
        let windowOriginX = windowFrame.origin.x.decimal
        let windowWidth = windowFrame.width.decimal
        let windowHeight = windowFrame.height.decimal
        let screenWidth = screen.frame.width.decimal
        let screenHeight = screen.visibleFrame.height.decimal
        self = .init(
            x: abs((windowOriginX - screenOriginX - xDelta) / screenWidth).rounded(),
            y: abs(upperWindowEdge / screenHeight).rounded(),
            w: min(
                1.0,
                abs(windowWidth / (screenWidth - dockWidth)).rounded()
            ),
            h: min(
                1.0,
                abs(windowHeight / screenHeight).rounded()
            )
        )
    }

    /// Returns a new `CGRect` with an absolute representation of this matrix on the given `screen`. Using Accessibility APIs, it's `origin` and `size`
    /// may be applied to any window to reposition and resize it's frame.
    public func rect<Screen: WindowContainer>(
        forScreen screen: Screen
    ) -> CGRect where Screen.This == Screen {
        let primaryScreen = Screen.primary
        let screenRect = screen.visibleFrame
        var rect = CGRect()
        rect.origin = CGPoint()
        rect.origin.x = screenRect.origin.x
            + (screenRect.size.width * CGFloat(x.fraction)).rounded(.toNearestOrAwayFromZero)
        rect.origin.y = (primaryScreen?.frame ?? .zero).height
            - screen.frame.height
            - screen.frame.origin.y
            + screen.menuBarThickness
            + (CGFloat(y.fraction) * screenRect.size.height).rounded(.toNearestOrAwayFromZero)
        rect.size = CGSize()
        rect.size.height = (CGFloat(h.fraction) * screenRect.size.height).rounded(.toNearestOrAwayFromZero)
        rect.size.width = (CGFloat(w.fraction) * screenRect.size.width).rounded(.toNearestOrAwayFromZero)
        // Ensure the frame height does not exceed the bottom of `self` or the dock's upper edge
        let maxHeight = screenRect.maxY - rect.origin.y
        if rect.size.height > maxHeight {
            rect.size.height = maxHeight
        }
        return rect
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
