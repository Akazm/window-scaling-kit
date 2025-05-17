import CoreGraphics
import Foundation

/// A type-safe wrapper around a window dictionary returned by `CGWindowListCopyWindowInfo`.
public struct CGWindowInfo: CustomStringConvertible, Sendable {
    public let windowNumber: Int
    public let ownerPID: pid_t
    public let ownerName: String
    public let windowLayer: Int
    public let bounds: CGRect
    public let isOnScreen: Bool
    public let windowAlpha: Double
    public let windowName: String?
    public let sharingState: Int?
    public let memoryUsage: Int?
    public let storeType: Int?

    public var description: String {
        var result = "\(ownerName) (PID: \(ownerPID), Window: \(windowNumber), Layer: \(windowLayer))"
        if let name = windowName {
            result += " – \"\(name)\""
        }
        return result
    }

    @MainActor
    public init?(dictionary: [String: Any]) {
        guard
            let windowNumber = dictionary[kCGWindowNumber as String] as? Int,
            let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
            let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
            let windowLayer = dictionary[kCGWindowLayer as String] as? Int,
            let boundsDict = dictionary[kCGWindowBounds as String] as? [String: CGFloat],
            let isOnScreen = dictionary[kCGWindowIsOnscreen as String] as? Bool,
            let alpha = dictionary[kCGWindowAlpha as String] as? Double
        else {
            return nil
        }
        self.windowNumber = windowNumber
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.windowLayer = windowLayer
        self.isOnScreen = isOnScreen
        self.sharingState = dictionary[kCGWindowSharingState as String] as? Int
        self.memoryUsage = dictionary[kCGWindowMemoryUsage as String] as? Int
        self.storeType = dictionary[kCGWindowStoreType as String] as? Int
        windowAlpha = alpha
        windowName = dictionary[kCGWindowName as String] as? String
        bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
    }

    public var isStatusIcon: Bool {
        bounds.minY == 0 && windowLayer == 25
    }

    @MainActor
    public static func from(_: CGWindowListOption, _: CGWindowID) -> [CGWindowInfo] {
        let cgWindows = (CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: AnyObject]]
        )
        guard let cgWindows else {
            return []
        }
        return cgWindows.compactMap { CGWindowInfo(dictionary: $0) }
    }
}
