import CoreGraphics

/// Provides trigonometry and geometry extension methods for [NSScreen](https://developer.apple.com/documentation/appkit/nsscreen).
///
/// In case device-independent, automated tests are of concern, you can provide your own implementation of this protocol.
public protocol WindowContainer: Hashable {
    /// *Tricks* the compiler into allowing non-final `Self` return types. Extensions should therefore always be constrained to `This == Self`.
    associatedtype This = Self where This: WindowContainer, This: Hashable
    /// The screen with the current frontmost window
    @MainActor static var activeScreen: This? { get }
    /// See: [screens](https://developer.apple.com/documentation/appkit/nsscreen/1388393-screens)
    static var screens: [This] { get }
    /// See: [main](https://developer.apple.com/documentation/appkit/nsscreen/1388371-main)
    static var main: This? { get }

    /// See: [localizedName](https://developer.apple.com/documentation/appkit/nsscreen/3228043-localizedname)
    var localizedName: String { get }
    /// See: [frame](https://developer.apple.com/documentation/appkit/nsscreen/1388387-frame)
    var frame: CGRect { get }
    /// See: [visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/1388369-visibleframe)
    var visibleFrame: CGRect { get }
    /// The maximum of either
    /// [NSStatusBar.system.thickness](https://developer.apple.com/documentation/appkit/nsstatusbar/1534591-thickness) or
    /// the [auxiliaryTopLeftArea](https://developer.apple.com/documentation/appkit/nsscreen/3882915-auxiliarytopleftarea)'s
    /// height
    var menuBarThickness: CGFloat { get }
    /// The wallpaper
    var desktopPicture: CGImage? { get }
}
