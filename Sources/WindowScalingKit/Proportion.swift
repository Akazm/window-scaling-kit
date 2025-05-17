import CoreGraphics
import Foundation

/// A type that represents a proportional value either as a fraction or a percentage.
public enum Proportion: Sendable, Hashable {
    /// A fractional representation of the value (e.g., 0.5 for 50%).
    case fractional(Decimal)
    /// A percentage representation of the value (e.g., 50 for 50%).
    case percentual(Decimal)

    /// Value as a fraction (between 0 and 1).
    public var fraction: Decimal {
        switch self {
            case let .fractional(value):
                value
            case let .percentual(value):
                value / 100.0
        }
    }

    /// Value as percentage (between 0 and 100).
    public var percentage: Decimal {
        switch self {
            case let .fractional(value):
                value * 100
            case let .percentual(value):
                value
        }
    }
    
    public static var zero: Self { .percentual(0) }
    
    public var isNaN: Bool {
        switch self {
            case .fractional(let value):
                value.isNaN
            case .percentual(let value):
                value.isNaN
        }
    }
    
    public static func == (lhs: Proportion, rhs: Proportion) -> Bool {
        lhs.percentage == rhs.percentage
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(percentage)
    }
}

extension Proportion {

    public static func + (lhs: Proportion, rhs: Proportion) -> Proportion {
        .percentual(lhs.percentage + rhs.percentage)
    }

    public static func - (lhs: Proportion, rhs: Proportion) -> Proportion {
        .percentual(lhs.percentage - rhs.percentage)
    }

    public static func * (lhs: Proportion, rhs: Proportion) -> Proportion {
        .percentual(lhs.percentage * rhs.percentage)
    }

    public static func / (lhs: Proportion, rhs: Proportion) -> Proportion {
        .percentual(lhs.percentage / rhs.percentage)
    }
    
    public static func *= (lhs: inout Proportion, rhs: Proportion) {
        lhs = .percentual(lhs.percentage * rhs.percentage)
    }
    
}

extension Proportion: Comparable {
    
    public static func < (lhs: Proportion, rhs: Proportion) -> Bool {
        lhs.percentage < rhs.percentage
    }
    
}

extension Proportion: Codable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.percentage)
    }
    
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self = try .percentual(container.decode(Decimal.self))
    }
    
}

extension Proportion: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
            case .fractional(let value):
                "\(value)"
            case .percentual(let value):
                "\(value)%"
        }
    }
    
}
