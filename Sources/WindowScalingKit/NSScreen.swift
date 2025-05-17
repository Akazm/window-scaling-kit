import AppKit
import AXKit

extension NSScreen: WindowContainer {
    public var menuBarThickness: CGFloat {
        let statusBarThickness = NSStatusBar.system.thickness > 0
            ? NSStatusBar.system.thickness + 3
            : NSStatusBar.system.thickness
        return if #available(macOS 12, *) {
            if let auxiliaryHeight = auxiliaryTopLeftArea?.height {
                max(statusBarThickness, auxiliaryHeight)
            } else {
                statusBarThickness
            }
        } else {
            statusBarThickness
        }
    }

    @MainActor public static var activeScreen: NSScreen? {
        guard
            let frontmost = try? AXWindow.focusedWindow(),
            let rect = try? frontmost.getFrame()
        else {
            return nil
        }
        return screenContaining(rect: rect)
    }

    // TODO: Move to application layer code
    public var desktopPicture: CGImage? {
        guard let windows = CGWindowListCopyWindowInfo(
            CGWindowListOption.optionOnScreenOnly,
            CGWindowID(0)
        ) as? [NSDictionary] else {
            return nil
        }
        let windowsOfIntereset = windows.filter { window in
            if #available(macOS 14, *) {
                return window["kCGWindowOwnerName"] as? String == "Dock" &&
                    (window["kCGWindowName"] as? String)?.hasPrefix("Wallpaper") == true
            } else {
                return window["kCGWindowOwnerName"] as? String == "Dock" &&
                    (window["kCGWindowName"] as? String)?.hasPrefix("Desktop Picture") == true
            }
        }
        for i in 0 ..< windowsOfIntereset.count {
            let window = windowsOfIntereset[i]
            let bounds = window["kCGWindowBounds"] as! NSDictionary
            let x = bounds["X"] as! CGFloat
            let y = bounds["Y"] as! CGFloat
            if CGPoint(x: x, y: y) != frame.origin {
                continue
            }
            return CGWindowListCreateImage(
                CGRect.zero,
                CGWindowListOption(arrayLiteral: CGWindowListOption.optionIncludingWindow),
                CGWindowID(window["kCGWindowNumber"] as! Int64),
                []
            )
        }
        return nil
    }
}

// swiftlint:enable force_cast
