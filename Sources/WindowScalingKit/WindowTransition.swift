import CoreGraphics
import Foundation

/// Represents a transition or transformation that can be applied to a window, such as moving or resizing.
/// This enum is `Sendable` and `Hashable`, making it suitable for use across concurrency boundaries and in sets or dictionaries.
public enum WindowTransition: Sendable, Hashable {
    
    /// Moves the window to an absolute position defined by the provided coordinates.
    ///
    /// - Parameter value: The exact coordinates where the window should be placed.
    case absolute(_ value: WindowCoordinates)
    
    /// Targets a neighbouring screen based on a compass-like coordinate system rotated by 90 degrees.
    ///
    /// The angle is in degrees and determines the relative direction of the target display:
    /// - 0 or 360 degrees points to the screen to the right.
    /// - 90 degrees points to the screen directly above.
    /// - 180 degrees points to the screen to the left.
    /// - 270 degrees points to the screen directly below.
    ///
    /// Intermediate (non-right-angle) values are also supported.
    ///
    /// - Parameters:
    ///   - a: The horizontal coordinate in screen space.
    ///   - b: The vertical coordinate in screen space.
    case moveToScreen(_ a: UInt16, _ b: UInt16)
    
    /// Snaps the window into the next possible tile
    ///
    /// - Parameter breakpoints: The set of horizontal size ratios or positions to snap to.
    case snapToGrid(ResizeBehavior, _ breakpoints: WindowTransitionBreakpoints)
    
    /// Moves the window left across predefined breakpoints.
    ///
    /// - Parameter breakpoints: The set of horizontal size ratios or positions to snap to.
    case moveLeft(_ breakpoints: WindowTransitionBreakpoints)
    
    /// Moves the window right across predefined breakpoints.
    ///
    /// - Parameter breakpoints: The set of horizontal size ratios or positions to snap to.
    case moveRight(_ breakpoints: WindowTransitionBreakpoints)
    
    /// Moves the window upward across predefined breakpoints.
    ///
    /// - Parameter breakpoints: The set of vertical size ratios or positions to snap to.
    case moveUp(_ breakpoints: WindowTransitionBreakpoints)
    
    /// Moves the window downward across predefined breakpoints.
    ///
    /// - Parameter breakpoints: The set of vertical size ratios or positions to snap to.
    case moveDown(_ breakpoints: WindowTransitionBreakpoints)
    
    /// Resizes the window from the left edge, adjusting it based on the given behavior and breakpoints.
    ///
    /// - Parameters:
    ///   - behavior: Increases the window's width to the left when set to `.grow`, shrinks it otherwise.
    ///   - breakpoints: The set of horizontal size ratios or positions to snap to.
    case resizeLeft(ResizeBehavior, _ breakpoints: WindowTransitionBreakpoints)
    
    /// Resizes the window from the right edge, adjusting it based on the given behavior and breakpoints.
    ///
    /// - Parameters:
    ///   - behavior: Increases the window's width to the right when set to `.grow`, shrinks it otherwise.
    ///   - breakpoints: The set of horizontal size ratios or positions to snap to.
    case resizeRight(ResizeBehavior, _ breakpoints: WindowTransitionBreakpoints)
    
    /// Resizes the window from the top edge, adjusting it based on the given behavior and breakpoints.
    ///
    /// - Parameters:
    ///   - behavior: Increases the window's height to the top when set to `.grow`, shrinks it otherwise.
    ///   - breakpoints: The set of vertical size ratios or positions to snap to.
    case resizeTop(ResizeBehavior, _ breakpoints: WindowTransitionBreakpoints)
    
    /// Resizes the window from the bottom edge, adjusting it based on the given behavior and breakpoints.
    ///
    /// - Parameters:
    ///   - behavior: Increases the window's height to the bottom when set to `.grow`, shrinks it otherwise.
    ///   - breakpoints: The set of vertical size ratios or positions to snap to.
    case resizeBottom(ResizeBehavior, _ breakpoints: WindowTransitionBreakpoints)
}

extension WindowTransition: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
            case let .absolute(value):
                return "absolute(\(value))"
            case let .moveToScreen(a, b):
                return "moveToScreen(\(a), \(b))"
            case let .moveLeft(breakpoints):
                return "moveLeft(breakpoints: \(breakpoints))"
            case let .moveRight(breakpoints):
                return "moveRight(breakpoints: \(breakpoints))"
            case let .resizeLeft(direction, breakpoints):
                return "resizeLeft(\(direction), breakpoints: \(breakpoints))"
            case let .resizeRight(direction, breakpoints):
                return "resizeRight(\(direction), breakpoints: \(breakpoints))"
            case let .moveUp(breakpoints):
                return "moveUp(\(breakpoints)"
            case let .moveDown(breakpoints):
                return "moveDown(\(breakpoints)"
            case let .resizeTop(direction, breakpoints):
                return "resizeTop(\(direction), breakpoints: \(breakpoints))"
            case let .resizeBottom(direction, breakpoints):
                return "resizeBottom(\(direction), breakpoints: \(breakpoints))"
            case let .snapToGrid(behavior, breakpoints):
                return "snapToGrid(\(behavior), breakpoints: \(breakpoints))"
        }
    }
    
}

/// Computes the resulting frame (`CGRect`) for a window after applying the window transition,
/// based on its current position and the screen it resides on.
///
/// - Parameters:
///   - screen: The screen or display the window is currently on. Must conform to `WindowContainer`.
///   - currentFrame: The current frame (`CGRect`) of the window before applying the transition.
///
/// - Returns: A new `CGRect` representing the window's frame after the transition, or `nil`
///   if the transition cannot be resolved.
///
/// - Note:
///   The method supports moving and resizing transitions, including direction-based transitions
///   across breakpoints, as well as relative movement to neighboring displays.
public extension WindowTransition {
    
    var breakpoints: WindowTransitionBreakpoints {
        switch self {
            case .snapToGrid(_, let breakpoints):
                breakpoints
            case .moveLeft(let breakpoints):
                breakpoints
            case .moveRight(let breakpoints):
                breakpoints
            case .moveUp(let breakpoints):
                breakpoints
            case .moveDown(let breakpoints):
                breakpoints
            case .resizeLeft(_, let breakpoints):
                breakpoints
            case .resizeRight(_, let breakpoints):
                breakpoints
            case .resizeTop(_, let breakpoints):
                breakpoints
            case .resizeBottom(_, let breakpoints):
                breakpoints
            default:
                .init([])
        }
    }
    
    func rect<W: WindowContainer>(
        onScreen screen: W, from currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let currentCoordinates = WindowCoordinates(ofWindowFrame: currentFrame, onScreen: screen)
        switch self {
            case let .absolute(value):
                return value.rect(forScreen: screen)
            case let .moveToScreen(alpha, beta):
                return handleMoveToScreen(
                    alpha: alpha,
                    beta: beta,
                    screen: screen,
                    currentCoordinates: currentCoordinates
                )
            case let .moveUp(breakpoints):
                return handleMoveTop(
                    breakpoints: breakpoints.on(axis: .vertical),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .moveDown(breakpoints):
                return handleMoveBottom(
                    breakpoints: breakpoints.on(axis: .vertical),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .moveLeft(breakpoints):
                return handleMoveLeft(
                    breakpoints: breakpoints.on(axis: .horizontal),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .moveRight(breakpoints):
                return handleMoveRight(
                    breakpoints: breakpoints.on(axis: .horizontal),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .resizeLeft(direction, breakpoints):
                return handleResizeLeft(
                    direction: direction,
                    breakpoints: breakpoints.on(axis: .horizontal),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .resizeRight(direction, breakpoints):
                return handleResizeRight(
                    direction: direction,
                    breakpoints: breakpoints.on(axis: .horizontal),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame)
            case let .resizeTop(direction, breakpoints):
                return handleResizeTop(
                    direction: direction,
                    breakpoints: breakpoints.on(axis: .vertical),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .resizeBottom(direction, breakpoints):
                return handleResizeBottom(
                    direction: direction,
                    breakpoints: breakpoints.on(axis: .vertical),
                    screen: screen,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
            case let .snapToGrid(behavior, breakpoints):
                return handleSnapToGrid(
                    behavior: behavior,
                    screen: screen,
                    breakpoints: breakpoints,
                    currentCoordinates: currentCoordinates,
                    currentFrame: currentFrame
                )
        }
    }
    
    private func handleMoveToScreen<W: WindowContainer>(
        alpha: UInt16,
        beta: UInt16,
        screen: W,
        currentCoordinates: WindowCoordinates
    ) -> CGRect? where W.This == W {
        guard let newScreen = screen.findScreenBetween(alpha: alpha, andBeta: beta) else {
            return nil
        }
        return currentCoordinates.rect(forScreen: newScreen)
    }
    
    private func handleMoveTop<W: WindowContainer>(
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: .shrink
        )
        switch closestCoordinate?.coordinate {
            case .maxY:
                return currentCoordinates
                    .setting(.y(currentCoordinates.y + closestCoordinate!.delta, mode: .move))
                    .rect(forScreen: screen)
            case .y:
                return currentCoordinates
                    .setting(.y(closestCoordinate!.breakpoint, mode: .move))
                    .rect(forScreen: screen)
            default:
                return nil
        }
    }
    
    private func handleMoveBottom<W: WindowContainer>(
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: .grow
        )
        switch closestCoordinate?.coordinate {
            case .maxY:
                return currentCoordinates
                    .setting(.y(currentCoordinates.y + closestCoordinate!.delta, mode: .move))
                    .rect(forScreen: screen)
            case .y:
                return currentCoordinates
                    .setting(.y(closestCoordinate!.breakpoint, mode: .move))
                    .rect(forScreen: screen)
            default:
                return nil
        }
    }
    
    private func handleMoveLeft<W: WindowContainer>(
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: .shrink
        )
        switch closestCoordinate?.coordinate {
            case .maxX:
                return currentCoordinates
                    .setting(.x(currentCoordinates.x + closestCoordinate!.delta, mode: .move))
                    .rect(forScreen: screen)
            case .x:
                return currentCoordinates
                    .setting(.x(closestCoordinate!.breakpoint, mode: .move))
                    .rect(forScreen: screen)
            default:
                return nil
        }
    }
    
    private func handleMoveRight<W: WindowContainer>(
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: .grow
        )
        switch closestCoordinate?.coordinate {
            case .maxX:
                return currentCoordinates
                    .setting(.x(currentCoordinates.x + closestCoordinate!.delta, mode: .move))
                    .rect(forScreen: screen)
            case .x:
                return currentCoordinates
                    .setting(.x(closestCoordinate!.breakpoint, mode: .move))
                    .rect(forScreen: screen)
            default:
                return nil
        }
    }
    
    private func handleResizeLeft<W: WindowContainer>(
        direction: ResizeBehavior,
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: direction.inverted
        ) { anchor in
            switch anchor.coordinate {
                case .maxX:
                    false
                default:
                    true
            }
        }
        guard let closestCoordinate else {
            return nil
        }
        return currentCoordinates
            .setting(.x(closestCoordinate.breakpoint, mode: .resize))
            .rect(forScreen: screen)
    }
    
    private func handleResizeRight<W: WindowContainer>(
        direction: ResizeBehavior,
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: direction
        ) { anchor in
            switch anchor.coordinate {
                case .x:
                    false
                default:
                    true
            }
        }
        guard let closestCoordinate else {
            return nil
        }
        return currentCoordinates
            .setting(.maxX(closestCoordinate.breakpoint, mode: .resize))
            .rect(forScreen: screen)
    }
    
    private func handleResizeTop<W: WindowContainer>(
        direction: ResizeBehavior,
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: direction.inverted
        ) { anchor in
            switch anchor.coordinate {
                case .maxY:
                    false
                default:
                    true
            }
        }
        guard let closestCoordinate else {
            return nil
        }
        return currentCoordinates
            .setting(.y(closestCoordinate.breakpoint, mode: .resize))
            .rect(forScreen: screen)
    }
    
    private func handleResizeBottom<W: WindowContainer>(
        direction: ResizeBehavior,
        breakpoints: WindowTransitionBreakpoints,
        screen: W,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let closestCoordinate = currentCoordinates.closestAnchor(
            along: breakpoints,
            behavior: direction
        ) { anchor in
            switch anchor.coordinate {
                case .y:
                    false
                default:
                    true
            }
        }
        guard let closestCoordinate else {
            return nil
        }
        return currentCoordinates
            .setting(.maxY(closestCoordinate.breakpoint, mode: .resize))
            .rect(forScreen: screen)
    }
    
    private func handleSnapToGrid<W: WindowContainer>(
        behavior: ResizeBehavior,
        screen: W,
        breakpoints: WindowTransitionBreakpoints,
        currentCoordinates: WindowCoordinates,
        currentFrame: CGRect
    ) -> CGRect? where W.This == W {
        let horizontalBreakpoints = breakpoints.on(axis: .horizontal)
        let verticalBreakpoints = breakpoints.on(axis: .vertical)
        let closestTopCoordinate = currentCoordinates.closestAnchor(
            along: verticalBreakpoints,
            behavior: behavior.inverted
        ) { anchor in
            switch anchor.coordinate {
                case .maxY:
                    false
                default:
                    true
            }
        }
        let closestRightCoordinate = currentCoordinates.closestAnchor(
            along: horizontalBreakpoints,
            behavior: behavior.inverted
        ) { anchor in
            switch anchor.coordinate {
                case .x:
                    false
                default:
                    true
            }
        }
        let closestBottomCoordinate = currentCoordinates.closestAnchor(
            along: verticalBreakpoints,
            behavior: behavior
        ) { anchor in
            switch anchor.coordinate {
                case .y:
                    false
                default:
                    true
            }
        }
        let closestLeftCoordinate = currentCoordinates.closestAnchor(
            along: horizontalBreakpoints,
            behavior: behavior.inverted
        ) { anchor in
            switch anchor.coordinate {
                case .maxX:
                    false
                default:
                    true
            }
        }
        var newCoordinates = WindowCoordinates(
            x: closestLeftCoordinate?.breakpoint ?? currentCoordinates.x,
            y: closestTopCoordinate?.breakpoint ?? currentCoordinates.y,
            w: currentCoordinates.w,
            h: currentCoordinates.h
        )
        if let closestBottomCoordinate = closestBottomCoordinate {
            newCoordinates = newCoordinates.setting(.maxY(closestBottomCoordinate.breakpoint, mode: .resize))
        }
        if let closestRightCoordinate = closestRightCoordinate {
            newCoordinates = newCoordinates.setting(.maxX(closestRightCoordinate.breakpoint, mode: .resize))
        }
        return newCoordinates.rect(forScreen: screen)
    }
    
}
