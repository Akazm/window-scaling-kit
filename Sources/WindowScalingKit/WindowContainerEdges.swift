import AppKit
import AXKit

private extension CGRect {
    func subtracting(_ other: CGRect) -> [CGRect] {
        guard intersects(other) else { return [self] }
        
        var result: [CGRect] = []
        
        // Left slice
        if minX < other.minX {
            result.append(CGRect(x: minX, y: minY, width: other.minX - minX, height: height))
        }
        
        // Right slice
        if maxX > other.maxX {
            result.append(CGRect(x: other.maxX, y: minY, width: maxX - other.maxX, height: height))
        }
        
        // Top slice
        if maxY > other.maxY {
            let topRect = CGRect(
                x: max(minX, other.minX),
                y: other.maxY,
                width: min(maxX, other.maxX) - max(minX, other.minX),
                height: maxY - other.maxY
            )
            if !topRect.isEmpty {
                result.append(topRect)
            }
        }
        
        // Bottom slice
        if minY < other.minY {
            let bottomRect = CGRect(
                x: max(minX, other.minX),
                y: minY,
                width: min(maxX, other.maxX) - max(minX, other.minX),
                height: other.minY - minY
            )
            if !bottomRect.isEmpty {
                result.append(bottomRect)
            }
        }
        
        return result
    }
}

public extension WindowContainer where Self.This == Self {
    /// Returns edges of all windows as relative coordinates (values between 0 and 100)
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
                return screenRect.intersects(window.bounds)
                    ? window
                    : nil
            }
        let activeWindowCoordinates = WindowCoordinates(ofWindowFrame: activeWindow, onScreen: self)
        var results = Set<WindowTransitionBreakpoints.Value>()
        var visibleRects = [CGRect]()
        windowFrameLoop: for frame in cgWindowListFrames {
            var currentVisibleRects = [frame.bounds]
            for rect in visibleRects {
                currentVisibleRects = currentVisibleRects.flatMap { $0.subtracting(rect) }
                if currentVisibleRects.isEmpty {
                    continue windowFrameLoop
                }
            }
            
            visibleRects.append(frame.bounds)
            
            for visibleRect in currentVisibleRects {
                let visibleCoordinates = WindowCoordinates(ofWindowFrame: visibleRect, onScreen: self)
                if activeWindowCoordinates == visibleCoordinates {
                    continue
                }
                if axes.contains(.horizontal) {
                    results.insert(.x(visibleCoordinates.x, meta: ["windowInfo": frame]))
                    results.insert(.x(visibleCoordinates.maxX, meta: ["windowInfo": frame]))
                }
                if axes.contains(.vertical) {
                    results.insert(.y(visibleCoordinates.y, meta: ["windowInfo": frame]))
                    results.insert(.y(visibleCoordinates.maxY, meta: ["windowInfo": frame]))
                }
            }
        }
        return results
    }
}
