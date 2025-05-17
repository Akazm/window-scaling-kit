import AppKit
import AXKit

private extension CGRect {
    func subtracting(_ other: CGRect) -> CGRect {
        if other.contains(self) {
            return .null
        } else if intersects(other) {
            return divided(atDistance: other.height, from: .minYEdge).slice
        } else {
            return self
        }
    }
}

public extension WindowContainer where Self.This == Self {
    /// Returns edges of all windows as relative coordinates (values between 0 and 100)
    @MainActor
    func visibleEdges(on axes: WindowAxis) -> Set<WindowTransitionBreakpoints.Value> {
        guard let screenHeight = Self.screens.first?.frame.height,
              let activeWindow = try? AXWindow.focusedWindow()?.getFrame() else {
            return []
        }
        let cgWindows = CGWindowInfo.from([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let screenRect = CGRect(
            x: frame.origin.x,
            y: screenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        // Tooltips, as for example to be seen in Safari, will interfere with edge detection otherwise
        let commonTooltipHeight: CGFloat = 20
        // The common layer for 'normal' windows
        let commonWindowLayer = 0
        let cgWindowListFrames = cgWindows
            .compactMap { window -> CGWindowInfo? in
                guard
                    window.windowAlpha == 1.0,
                    window.windowLayer == commonWindowLayer,
                    window.bounds.height > commonTooltipHeight else {
                    return nil
                }
                return screenRect.intersects(window.bounds) && window.windowLayer == 0
                    ? window
                    : nil
            }
        var results = Set<WindowTransitionBreakpoints.Value>()
        var visibleRects = [CGRect]()
        windowFrameLoop: for frame in cgWindowListFrames {
            let windowCoordinates = WindowCoordinates(ofWindowFrame: frame.bounds, onScreen: self)
            let activeWindowCoordinates = WindowCoordinates(ofWindowFrame: activeWindow, onScreen: self)
            if activeWindowCoordinates == windowCoordinates {
                continue
            }
            var visibleRect = frame.bounds
            for rect in visibleRects {
                visibleRect = visibleRect.subtracting(rect)
                if visibleRect.isEmpty {
                    continue windowFrameLoop
                }
            }
            visibleRects.append(frame.bounds)
            if axes.contains(.horizontal) {
                results.insert(.x(windowCoordinates.x, meta: ["windowInfo": frame]))
                results.insert(.x(windowCoordinates.maxX, meta: ["windowInfo": frame]))
            }
            if axes.contains(.vertical) {
                results.insert(.y(windowCoordinates.y, meta: ["windowInfo": frame]))
                results.insert(.y(windowCoordinates.maxY, meta: ["windowInfo": frame]))
            }
        }
        return results
    }
}
