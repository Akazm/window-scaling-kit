import CoreGraphics
import Testing
@testable import WindowScalingKit

/// Resizing along the grid on ``MockScreen/landscape``, whose visible area is 3789 × 1488 pt at (0, 31)
@Suite struct WindowTransitionTests {

    static let grid: WindowTransitionBreakpoints = [00.00, 16.665, 25.00, 33.33, 50.00, 66.67, 75.00, 83.335, 100.0]
    static let screen = MockScreen.landscape
    static let fullHeight = CGRect(x: 0, y: 31, width: 947, height: 1488)
    static let fullWidth = CGRect(x: 0, y: 775, width: 3789, height: 744)

    /// Applies `transition` until it stops changing the frame, returning every frame on the way
    static func steps(
        of transition: WindowTransition, from frame: CGRect, minimumSize: CGSize = .zero
    ) -> [CGRect] {
        var frames = [CGRect]()
        var current = frame
        while let next = transition.rect(onScreen: screen, from: current, minimumSize: minimumSize), next != current {
            frames.append(next)
            current = next
            if frames.count > 20 {
                break
            }
        }
        return frames
    }

    /// The last step used to move the top onto the bottom edge, asking for a window without height
    @Test func shrinkingFromTheTopStopsAtTheLastBreakpointAboveTheBottom() {
        let frames = Self.steps(of: .resizeTop(.shrink, Self.grid), from: Self.fullHeight)
        #expect(frames.map(\.minY) == [279, 403, 527, 775, 1023, 1147, 1271])
        #expect(frames.allSatisfy { $0.maxY == Self.fullHeight.maxY })
        #expect(frames.last?.height == 248)
    }

    @Test func shrinkingFromTheBottomStopsAtTheLastBreakpointBelowTheTop() {
        let frames = Self.steps(of: .resizeBottom(.shrink, Self.grid), from: Self.fullHeight)
        #expect(frames.allSatisfy { $0.minY == Self.fullHeight.minY && $0.height > 0 })
        #expect(frames.last?.height == 248)
    }

    /// The screen is 3789 pt wide, so half of it is not a whole number of points: rounding origin and width each used to
    /// push the right edge out a point at that step, and further with every step after
    @Test func shrinkingFromEitherSideStopsBeforeTheOppositeEdge() {
        let fromLeft = Self.steps(of: .resizeLeft(.shrink, Self.grid), from: Self.fullWidth)
        let fromRight = Self.steps(of: .resizeRight(.shrink, Self.grid), from: Self.fullWidth)
        #expect(fromLeft.allSatisfy { $0.maxX == Self.fullWidth.maxX && $0.width > 0 })
        #expect(fromRight.allSatisfy { $0.minX == Self.fullWidth.minX && $0.width > 0 })
        #expect(fromLeft.last?.width == 631)
        #expect(fromRight.last?.width == 631)
    }

    /// A window that cannot get lower than 400 pt skips the breakpoints that would ask for less
    @Test func shrinkingFromTheTopRespectsTheMinimumHeight() {
        let minimumSize = CGSize(width: 0, height: 400)
        let frames = Self.steps(of: .resizeTop(.shrink, Self.grid), from: Self.fullHeight, minimumSize: minimumSize)
        #expect(frames.map(\.minY) == [279, 403, 527, 775, 1023])
        #expect(frames.allSatisfy { $0.height >= 400 && $0.maxY == Self.fullHeight.maxY })
    }

    @Test func noFittingBreakpointLeavesTheWindowAlone() {
        let window = CGRect(x: 0, y: 1023, width: 947, height: 496)
        let minimumSize = CGSize(width: 0, height: 400)
        #expect(WindowTransition.resizeTop(.shrink, Self.grid).rect(onScreen: Self.screen, from: window, minimumSize: minimumSize) == nil)
        #expect(WindowTransition.resizeBottom(.shrink, Self.grid).rect(onScreen: Self.screen, from: window, minimumSize: minimumSize) == nil)
    }

    @Test func shrinkingFromTheLeftRespectsTheMinimumWidth() {
        let minimumSize = CGSize(width: 1000, height: 0)
        let frames = Self.steps(of: .resizeLeft(.shrink, Self.grid), from: Self.fullWidth, minimumSize: minimumSize)
        #expect(!frames.isEmpty)
        #expect(frames.allSatisfy { $0.width >= 1000 && $0.maxX == Self.fullWidth.maxX })
        #expect(frames.last?.minX == 2526)
    }

    /// Growing is never held back by a minimum size the window already exceeds
    @Test func growingIgnoresTheMinimumSize() {
        let window = CGRect(x: 0, y: 1023, width: 947, height: 496)
        let grown = WindowTransition.resizeTop(.grow, Self.grid)
            .rect(onScreen: Self.screen, from: window, minimumSize: CGSize(width: 0, height: 400))
        #expect(grown == CGRect(x: 0, y: 775, width: 947, height: 744))
    }

    /// A frame reaching into the menu bar, like a full-screen overlay window, used to be mirrored below the top
    @Test func aFrameReachingAboveTheVisibleAreaStartsAtItsTop() {
        let overlay = WindowCoordinates(ofWindowFrame: CGRect(x: 0, y: 0, width: 3789, height: 1598), onScreen: Self.screen)
        #expect(overlay.y.percentage == 0)
        #expect(overlay.x.percentage == 0)
    }
}
