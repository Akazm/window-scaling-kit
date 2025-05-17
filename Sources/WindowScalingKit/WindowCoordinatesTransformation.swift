import CoreGraphics
import Foundation

public extension WindowCoordinates {
    
    /// Represents a window coordinate (x, y, maxX, or maxY) and the mode by which it should be applied (move or resize).
    enum CoordinateValue: Sendable {
        /// The x-coordinate with a mode (move or resize).
        case x(Proportion, mode: SetCoordinateMode)
        /// The y-coordinate with a mode (move or resize).
        case y(Proportion, mode: SetCoordinateMode)
        /// The maximum x-coordinate with a mode (move or resize).
        case maxX(Proportion, mode: SetCoordinateMode)
        /// The maximum y-coordinate with a mode (move or resize).
        case maxY(Proportion, mode: SetCoordinateMode)
    }

    /// Indicates how a coordinate should be interpreted when being set.
    enum SetCoordinateMode: Sendable {
        /// Indicates the window should be moved to the specified coordinate.
        case move
        /// Indicates the window should be resized so that the coordinate becomes the new edge.
        case resize
    }

    /// Represents a proportional span between two values.
    struct Span: Sendable {
        /// The minimum bound of the span.
        public let min: Proportion
        /// The maximum bound of the span.
        public let max: Proportion

        /// Initializes a span with ``Proportion`` values.
        /// - Parameters:
        ///   - min: The starting proportion.
        ///   - max: The ending proportion.
        public init(min: Proportion, max: Proportion) {
            self.min = min
            self.max = max
        }

        /// Initializes a span with `Decimal` values, which are converted to `Proportion.percentual`.
        /// - Parameters:
        ///   - min: The starting value, as a percentage.
        ///   - max: The ending value, as a percentage.
        public init(min: Decimal, max: Decimal) {
            self.min = .percentual(min)
            self.max = .percentual(max)
        }
    }

    /// Initializes window coordinates using spans for both horizontal and vertical dimensions.
    /// - Parameters:
    ///   - x: Horizontal span representing the start and end x-values.
    ///   - y: Vertical span representing the start and end y-values.
    init(x: Span, y: Span) {
        self = .init(x: x.min, y: y.min, w: x.max - x.min, h: y.max - y.min)
    }

    /// Initializes window coordinates using a horizontal span, and fixed vertical position and height.
    /// - Parameters:
    ///   - x: Horizontal span for x and width.
    ///   - y: Y-origin.
    ///   - h: Height of the window.
    init(x: Span, y: Proportion, h: Proportion) {
        self = .init(x: x.min, y: y, w: x.max - x.min, h: h)
    }

    /// Initializes window coordinates using a vertical span, and fixed horizontal position and width.
    /// - Parameters:
    ///   - x: X-origin.
    ///   - w: Width of the window.
    ///   - y: Vertical span for y and height.
    init(x: Proportion, w: Proportion, y: Span) {
        self = .init(x: x, y: y.min, w: w, h: y.max - y.min)
    }

    /// Returns a copy of the window coordinates with one of the coordinate values set or adjusted.
    ///
    /// - Parameter coordinate: A `CoordinateValue` specifying which coordinate to set and how.
    /// - Returns: A new `WindowCoordinates` with the updated value.
    func setting(_ coordinate: CoordinateValue) -> WindowCoordinates {
        switch coordinate {
            case let .x(newX, mode):
                switch mode {
                    case .move:
                        let maxX = .percentual(100) - w
                        let clampedX = max(.zero, min(newX, maxX))
                        return WindowCoordinates(x: clampedX, y: y, w: w, h: h)
                    case .resize:
                        let normalizedX = max(.zero, min(newX, x + w))
                        let newWidth = w + (x - normalizedX)
                        return WindowCoordinates(x: normalizedX, y: y, w: newWidth, h: h)
                }

            case let .y(newY, mode):
                switch mode {
                    case .move:
                        let maxY = .percentual(100) - h
                        let clampedY = max(.zero, min(newY, maxY))
                        return WindowCoordinates(x: x, y: clampedY, w: w, h: h)
                    case .resize:
                        let normalizedY = max(.zero, min(newY, y + h))
                        let newHeight = h + (y - normalizedY)
                        return WindowCoordinates(x: x, y: normalizedY, w: w, h: newHeight)
                }

            case let .maxX(maxX, mode):
                let normalizedMaxX = min(.percentual(100), maxX)
                switch mode {
                    case .move:
                        let width = normalizedMaxX - x
                        let adjustedX = max(.zero, min(x, .percentual(100) - width))
                        return WindowCoordinates(x: adjustedX, y: y, w: width, h: h)
                    case .resize:
                        let newWidth = normalizedMaxX - x
                        return WindowCoordinates(x: x, y: y, w: newWidth, h: h)
                }

            case let .maxY(maxY, mode):
                let normalizedMaxY = min(.percentual(100), maxY)
                switch mode {
                    case .move:
                        let height = normalizedMaxY - y
                        let adjustedY = max(.zero, min(y, .percentual(100) - height))
                        return WindowCoordinates(x: x, y: adjustedY, w: w, h: height)
                    case .resize:
                        let newHeight = normalizedMaxY - y
                        return WindowCoordinates(x: x, y: y, w: w, h: newHeight)
                }
        }
    }
}
