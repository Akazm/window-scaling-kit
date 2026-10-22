import CoreGraphics
import Testing
@testable import WindowScalingKit

/// A landscape primary screen next to a portrait screen whose top sits above the primary's, so that the
/// portrait screen's Cocoa and accessibility `y` ranges differ wildly.
struct MockScreen: WindowContainer {
    let localizedName: String
    let frame: CGRect
    let visibleFrame: CGRect

    /// Menu bar (31pt) at the top, Dock (79pt) at the bottom.
    static let landscape = MockScreen(
        localizedName: "Landscape",
        frame: CGRect(x: 0, y: 0, width: 3789, height: 1598),
        visibleFrame: CGRect(x: 0, y: 79, width: 3789, height: 1488)
    )

    /// Neither menu bar nor Dock reserve any space.
    static let portrait = MockScreen(
        localizedName: "Portrait",
        frame: CGRect(x: 3789, y: -648, width: 1440, height: 2560),
        visibleFrame: CGRect(x: 3789, y: -648, width: 1440, height: 2560)
    )

    /// The same screen once the Dock has followed the pointer onto it, with a menu bar of its own.
    static let portraitWithDock = MockScreen(
        localizedName: "Portrait",
        frame: CGRect(x: 3789, y: -648, width: 1440, height: 2560),
        visibleFrame: CGRect(x: 3789, y: -569, width: 1440, height: 2450)
    )

    static var screens: [MockScreen] { [landscape, portrait] }
    static var main: MockScreen? { landscape }
    static var activeScreen: MockScreen? { nil }

    var menuBarThickness: CGFloat { 31 }
    var desktopPicture: CGImage? { nil }

    func hash(into hasher: inout Hasher) {
        hasher.combine(localizedName)
        hasher.combine(visibleFrame.minY)
        hasher.combine(visibleFrame.height)
    }
}

@Suite struct WindowCoordinatesTests {

    @Test func axVisibleFrameIsTheVisibleFrameInAccessibilityCoordinates() {
        #expect(MockScreen.landscape.axVisibleFrame == CGRect(x: 0, y: 31, width: 3789, height: 1488))
        #expect(MockScreen.portrait.axVisibleFrame == CGRect(x: 3789, y: -314, width: 1440, height: 2560))
        #expect(MockScreen.portraitWithDock.axVisibleFrame == CGRect(x: 3789, y: -283, width: 1440, height: 2450))
    }

    /// Growing the bottom edge used to stop where the Cocoa `visibleFrame.maxY` would be in accessibility
    /// coordinates (a height of 2164 here), and to do nothing at all from there on.
    @Test(arguments: [1225, 2164] as [CGFloat])
    func growingTheBottomEdgeReachesTheDock(fromHeight height: CGFloat) {
        let window = CGRect(x: 3789, y: -283, width: 1440, height: height)
        let grown = WindowTransition.resizeBottom(.grow, [50, 100]).rect(onScreen: MockScreen.portraitWithDock, from: window)
        #expect(grown == CGRect(x: 3789, y: -283, width: 1440, height: 2450))
    }

    @Test func fillsAScreenWithoutMenuBar() {
        let rect = WindowCoordinates(x: 0, y: 0, w: 1, h: 1).rect(forScreen: MockScreen.portrait)
        #expect(rect == CGRect(x: 3789, y: -314, width: 1440, height: 2560))
    }

    @Test(arguments: [
        (MockScreen.landscape, CGRect(x: 0, y: 31, width: 3789, height: 1488)),
        (MockScreen.landscape, CGRect(x: 100, y: 400, width: 1800, height: 700)),
        (MockScreen.landscape, CGRect(x: 1894, y: 775, width: 1895, height: 744)),
        (MockScreen.portrait, CGRect(x: 3789, y: -314, width: 1440, height: 2560)),
        (MockScreen.portrait, CGRect(x: 3789, y: 966, width: 1440, height: 1280)),
        (MockScreen.portrait, CGRect(x: 3989, y: 100, width: 1000, height: 900)),
        (MockScreen.portraitWithDock, CGRect(x: 3789, y: -283, width: 1440, height: 2450)),
        (MockScreen.portraitWithDock, CGRect(x: 3789, y: 942, width: 1440, height: 1225)),
    ])
    func readingAFrameAndWritingItBackIsLossless(on screen: MockScreen, frame: CGRect) {
        let coordinates = WindowCoordinates(ofWindowFrame: frame, onScreen: screen)
        #expect(coordinates.rect(forScreen: screen) == frame)
    }
}
