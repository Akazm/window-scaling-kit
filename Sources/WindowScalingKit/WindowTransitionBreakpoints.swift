import Foundation

/// Represents a collection of valid breakpoint values used for window transitions,
/// such as snapping a window to specific size ratios or positions.
///
/// Breakpoints are represented as percentage-based values in the range `[0, 100]`,
/// and are used to guide movement or resizing operations in discrete steps along
/// horizontal and/or vertical axes.
public struct WindowTransitionBreakpoints: Sendable, Hashable {

    /// The set of validated breakpoint values, expressed as axis-bound proportions (as `.x` or `.y`).
    public let value: Set<Value>
    
    /// Initializes a new instance by filtering the input sequence to include only valid
    /// breakpoints (i.e., values in the range `[0, 100]` and not NaN).
    ///
    /// - Parameter sequence: A sequence of ``WindowTransitionBreakpoints/Value`` elements representing axis-bound proportions.
    init<S: Sequence>(_ sequence: S) where S.Element == Value {
        value = Set(
            sequence.filter { !$0.value.isNaN && $0.value >= .zero && $0.value <= .percentual(100) }
        )
    }

    /// Returns a new ``WindowTransitionBreakpoints`` instance in which breakpoints
    /// closer than the given tolerance are deduplicated.
    ///
    /// This is useful when values are very close together (e.g., due to floating-point
    /// imprecision or near-identical ratios), and only one should be retained.
    ///
    /// For example, if breakpoints `49.9` and `50.1` are present and the tolerance is `0.2`,
    /// only one will remain in the result.
    ///
    /// - Parameter tolerance: The maximum allowed difference (in percentage) between breakpoints to consider them equal.
    /// - Returns: A deduplicated ``WindowTransitionBreakpoints`` instance.
    public func with(tolerance: Proportion) -> Self {
        var xAxis: [Self.Value] = []
        var yAxis: [Self.Value] = []
        for value in self.value.filter({ $0.isOn(axis: .horizontal) }).sorted(by: { $0.percentage > $1.percentage }) {
            if let last = xAxis.last, abs(last.percentage - value.percentage) <= tolerance.percentage {
                xAxis.removeLast()
            }
            xAxis.append(value)
        }
        
        for value in self.value.filter({ $0.isOn(axis: .vertical) }).sorted(by: { $0.percentage > $1.percentage }) {
            if let last = yAxis.last, abs(last.percentage - value.percentage) <= tolerance.percentage {
                yAxis.removeLast()
            }
            yAxis.append(value)
        }
        return .init(Set(yAxis + xAxis))
    }

    /// Returns a new ``WindowTransitionBreakpoints`` instance by merging
    /// the current set of breakpoints with an additional sequence of percentage values,
    /// applied to the given axis (or axes).
    ///
    /// Only values within the valid range `[0, 100]` and not NaN are included.
    ///
    /// - Parameters:
    ///   - sequence: A sequence of `Decimal` percentage values to add as breakpoints.
    ///   - axis: The axis (or axes) to assign the new breakpoints to.
    /// - Returns: A merged ``WindowTransitionBreakpoints`` instance.
    public func merge<S: Sequence>(
        with sequence: S, asIfAppearingOnAxis axis: WindowAxis
    ) -> Self where S.Element == Decimal {
        .init(
            value
                .union(
                    sequence
                        .flatMap { [
                            axis.contains(.horizontal) ? .x(.percentual($0)) : nil,
                            axis.contains(.vertical) ? .y(.percentual($0)) : nil
                        ].compactMap(\.self)
                    }
                )
        )
    }

    /// Returns new ``WindowTransitionBreakpoints`` by merging
    /// the current set of breakpoints with another sequence of ``WindowTransitionBreakpoints/Value`` elements.
    ///
    /// - Parameter sequence: A sequence of ``WindowTransitionBreakpoints/Value`` elements.
    /// - Returns: A merged ``WindowTransitionBreakpoints`` instance.
    public func merge<S: Sequence>(with sequence: S) -> Self where S.Element == Self.Value {
        .init(value.union(sequence))
    }

    /// Filters the current breakpoints, returning only those on the specified axis.
    ///
    /// - Parameter axis: The axis to filter for.
    /// - Returns: A `WindowTransitionBreakpoints` instance containing only values on the specified axis.
    public func on(axis: WindowAxis) -> Self {
        .init(value.filter { $0.isOn(axis: axis) })
    }

    /// Represents a single axis-bound breakpoint value.
    ///
    /// Each breakpoint is associated with either the horizontal (X) or vertical (Y) axis
    /// and includes a proportional value and optional metadata.
    public enum Value: Sendable, Hashable {
        /// A breakpoint along the vertical (Y) axis.
        /// - Parameters:
        ///   - proportion: The proportional value of the breakpoint
        ///   - meta: Optional metadata associated with the breakpoint
        case y(Proportion, meta: [String: Sendable] = [:])
        
        /// A breakpoint along the horizontal (X) axis.
        /// - Parameters:
        ///   - proportion: The proportional value of the breakpoint
        ///   - meta: Optional metadata associated with the breakpoint
        case x(Proportion, meta: [String: Sendable] = [:])
        
        /// The raw proportional value of the breakpoint (e.g., `0.5` for 50%).
        public var value: Proportion {
            switch self {
                case .y(let proportionalValue, _):
                    proportionalValue
                case .x(let proportionalValue, _):
                    proportionalValue
            }
        }
        
        /// The percentage representation of the proportional value (e.g., `50` for 50%).
        public var percentage: Decimal {
            value.percentage
        }
        
        /// The fractional representation of the proportional value (e.g., `0.5` for 50%).
        public var fraction: Decimal {
            value.fraction
        }
        
        /// The axis that this breakpoint applies to.
        public var axis: WindowAxis {
            switch self {
                case .y:
                    .vertical
                case .x:
                    .horizontal
            }
        }

        /// Returns whether this breakpoint is on the given axis.
        ///
        /// - Parameter axis: The axis (or axes) to test.
        /// - Returns: `true` if the breakpoint is on the specified axis, otherwise `false`.
        public func isOn(axis: WindowAxis) -> Bool {
            switch axis {
                case .vertical:
                    if case .y = self {
                        true
                    } else {
                        false
                    }
                case .horizontal:
                    if case .x = self {
                        true
                    } else {
                        false
                    }
                case [.horizontal, .vertical]:
                    isOn(axis: .horizontal) || isOn(axis: .vertical)
                default:
                    false
            }
        }
        
        public static func == (lhs: WindowTransitionBreakpoints.Value, rhs: WindowTransitionBreakpoints.Value) -> Bool {
            if case .x = lhs, case .y = rhs {
                return false
            }
            if case .y = lhs, case .x = rhs {
                return false
            }
            return lhs.value == rhs.value
        }
        
        public func hash(into hasher: inout Hasher) {
            if case .x = self {
                hasher.combine(".x")
            }
            if case .y = self {
                hasher.combine(".y")
            }
            hasher.combine(self.value)
        }
        
    }
    
}

extension WindowTransitionBreakpoints.Value: Codable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
            case .y(let proportion, _):
                try container.encode("y(\(proportion))")
            case .x(let proportion, _):
                try container.encode("x(\(proportion))")
        }
    }
    
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let string = try container.decode(String.self)

        guard let openParenIndex = string.firstIndex(of: "("),
              let closeParenIndex = string.lastIndex(of: ")"),
              openParenIndex < closeParenIndex
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid format: \(string)")
        }

        let axis = String(string.prefix(upTo: openParenIndex))
        let decimalString = String(string[string.index(after: openParenIndex)..<closeParenIndex])

        guard let percentage = Decimal(string: decimalString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid decimal value: \(decimalString)")
        }
        let proportion = Proportion.percentual(percentage)

        switch axis {
            case "x":
                self = .x(proportion)
            case "y":
                self = .y(proportion)
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown axis prefix: \(axis)")
        }
    }
    
}

extension WindowTransitionBreakpoints: Codable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(value)
    }
    
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.value = try container.decode(Set<WindowTransitionBreakpoints.Value>.self)
    }
    
}

extension WindowTransitionBreakpoints.Value: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
            case .y(let proportion, _):
                ".y(\(proportion.debugDescription))"
            case .x(let proportion, _):
                ".x(\(proportion.debugDescription))"
        }
    }
    
}

extension WindowTransitionBreakpoints: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: Decimal...) {
        self.value = .init(elements.flatMap { [.x(.percentual($0)), .y(.percentual($0))] })
    }
    
}
