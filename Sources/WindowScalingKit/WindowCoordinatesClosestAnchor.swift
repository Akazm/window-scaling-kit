import Foundation

/// Represents a specific coordinate on a window, either by origin (`x`, `y`)
/// or by its far edge (`maxX`, `maxY`), expressed as a percentage of screen dimensions.
public enum WindowCoordinate: Sendable, Hashable {
    /// Distance from the left edge of the screen (0–100).
    case x(Proportion)
    /// Distance from the top edge of the screen (0–100).
    case y(Proportion)
    /// Distance from the left edge to the right edge of the window (0–100).
    case maxX(Proportion)
    /// Distance from the top edge to the bottom edge of the window (0–100).
    case maxY(Proportion)

    /// Extracts the raw value from the coordinate.
    var value: Proportion {
        switch self {
            case let .x(value), let .y(value), let .maxX(value), let .maxY(value):
                value
        }
    }
}

/// Represents the closest anchor point on a given axis (either the origin or edge of the window),
/// as compared to a target breakpoint.
public struct ClosestAnchor: Sendable, Hashable {
    /// The window coordinate (`x`, `y`, `maxX`, or `maxY`) being evaluated.
    public let coordinate: WindowCoordinate
    /// The breakpoint (in percentage) to which this coordinate is being compared.
    public let breakpoint: Proportion

    /// The signed difference between the coordinate and breakpoint.
    ///
    /// Positive if the coordinate is smaller than the breakpoint,
    /// negative if larger.
    public var delta: Proportion {
        breakpoint - coordinate.value
    }
}

public extension WindowCoordinates {
    
    /// Finds the closest anchor among a sequence of breakpoints along the specified axis,
    /// considering the intended `ResizeBehavior` and optional filtering logic.
    ///
    /// - Parameters:
    ///   - axis: The axis (`.horizontal`, `.vertical`, or both) to consider for the anchor.
    ///   - breakpoints: A sequence of `Decimal` values (percentages) representing snapping points.
    ///   - behavior: Whether the operation is a `.grow` or `.shrink`, affecting direction of tolerance.
    ///   - filter: Optional closure to filter valid anchor candidates.
    /// - Returns: The closest valid anchor or `nil` if none match the criteria.
    func closestAnchor(
        along breakpoints: WindowTransitionBreakpoints, behavior: ResizeBehavior,
        filter: ((ClosestAnchor) -> Bool) = { _ in true }
    ) -> ClosestAnchor? {
        breakpoints
            .value
            .compactMap { closestAnchor(for: $0, behavior: behavior, filter: filter) }
            .min {
                switch behavior {
                    case .shrink:
                        $1.delta < $0.delta
                    case .grow:
                        $0.delta < $1.delta
                }
            }
    }
    
    /// Evaluates a single breakpoint and returns the closest coordinate that would snap to it.
   ///
   /// - Parameters:
   ///   - axis: The axis to consider for coordinate evaluation.
   ///   - breakpoint: The specific percentage breakpoint being evaluated.
   ///   - behavior: Resize intent; `.shrink` prevents overshooting, `.grow` prevents undershooting.
   ///   - filter: A filter that can exclude anchors based on custom logic.
   /// - Returns: A valid `ClosestAnchor` for the given criteria, or `nil` if none found.
    func closestAnchor(
        for breakpoint: WindowTransitionBreakpoints.Value, behavior: ResizeBehavior, filter: ((ClosestAnchor) -> Bool)
    ) -> ClosestAnchor? {
        let axis = breakpoint.axis
        let x = WindowCoordinate.x(x)
        let y = WindowCoordinate.y(y)
        let maxX = WindowCoordinate.maxX(maxX)
        let maxY = WindowCoordinate.maxY(maxY)
        let breakpoint = WindowCoordinates.round(breakpoint.percentage)
        let tolerance: Decimal = 0.09
        let anchor: ClosestAnchor? = [x, y, maxX, maxY]
            .filter {
                return switch $0 {
                    case .maxX(let value), .x(let value):
                        axis.contains(.horizontal) && abs(value.percentage - breakpoint) > tolerance
                    case .maxY(let value), .y(let value):
                        axis.contains(.vertical) && abs(value.percentage - breakpoint) > tolerance
                }
            }
            .map { ClosestAnchor(coordinate: $0, breakpoint: .percentual(breakpoint)) }
            .filter(filter)
            .min { abs($0.delta.percentage) < abs($1.delta.percentage) }
        guard let anchor else {
            return nil
        }
        return switch behavior {
            case .shrink where anchor.coordinate.value.percentage < breakpoint:
                nil
            case .grow where anchor.coordinate.value.percentage > breakpoint:
                nil
            default:
                anchor
        }
    }
    
}
