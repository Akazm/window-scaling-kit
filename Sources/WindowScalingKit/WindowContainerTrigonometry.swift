import CoreGraphics
import SwiftUI

public typealias AngleRange = (start: UInt16, end: UInt16)

/// Represents a direction (`left`,`top`, `right`, `bottom`)
public struct Direction: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let left = Direction(rawValue: 1 << 0)
    public static let top = Direction(rawValue: 1 << 1)
    public static let right = Direction(rawValue: 1 << 2)
    public static let bottom = Direction(rawValue: 1 << 4)
}

public extension WindowContainer where This == Self {
    func screens(inDirection direction: Direction) -> Set<This> {
        var result: Set<This> = []
        if direction.contains(.left) {
            result = result.union(
                Self.screens.filter { screen in
                    if screen.frame.minX < self.frame.minX {
                        let shiftedRect = CGRect(
                            origin: CGPoint(
                                x: self.frame.origin.x,
                                y: screen.frame.origin.y
                            ),
                            size: screen.frame.size
                        )
                        return self.frame.intersects(shiftedRect)
                    }
                    return false
                }
            )
        }
        if direction.contains(.right) {
            result = result.union(
                Self.screens.filter { screen in
                    if screen.frame.minX > self.frame.minX {
                        let shiftedRect = CGRect(
                            origin: CGPoint(
                                x: self.frame.origin.x,
                                y: screen.frame.origin.y
                            ),
                            size: screen.frame.size
                        )
                        return self.frame.intersects(shiftedRect)
                    }
                    return false
                }
            )
        }
        if direction.contains(.top) {
            result = result.union(
                Self.screens.filter { screen in
                    if screen.frame.minY > self.frame.minY {
                        let shiftedRect = CGRect(
                            origin: CGPoint(
                                x: screen.frame.origin.x,
                                y: self.frame.origin.y
                            ),
                            size: screen.frame.size
                        )
                        return self.frame.intersects(shiftedRect)
                    }
                    return false
                }
            )
        }
        if direction.contains(.bottom) {
            result = result.union(
                Self.screens.filter { screen in
                    if screen.frame.minY < self.frame.minY {
                        let shiftedRect = CGRect(
                            origin: CGPoint(
                                x: screen.frame.origin.x,
                                y: self.frame.origin.y
                            ),
                            size: screen.frame.size
                        )
                        return self.frame.intersects(shiftedRect)
                    }
                    return false
                }
            )
        }
        return result
    }

    /// Locates a neighbour alongside a *compass* (rotated by 90 degrees) at the given angle in degrees, where a value ...
    ///
    /// - ... of 90 degrees points to the display directly above,
    /// - ... of 180 degrees points to the display directly to the left,
    /// - ... of 270 degrees points to the display directly below,
    /// - ... of 0 or 360 degrees points to the display to the right
    ///
    /// Intermediate values are valid as well.
    func findScreenAtAngle(degrees: Double) -> This? {
        let ownMid = CGPoint(x: frame.midX, y: frame.midY)
        return Self.screens
            .filter { (screen: This) in
                screen != self
            }.filter { (screen: WindowContainer) -> Bool in
                let otherMid = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
                let radius = sqrt(
                    pow(otherMid.x - ownMid.x, 2) +
                        pow(otherMid.y - ownMid.y, 2)
                )
                let pointAtAngle = CGPoint(
                    x: Double(ownMid.x) + Double(radius) * cos(Angle(degrees: degrees).radians),
                    y: Double(ownMid.y) + Double(radius) * sin(Angle(degrees: degrees).radians)
                )
                return screen.frame.contains(pointAtAngle)
            }.sorted { (screenA: This, screenB: This) in
                let distanceOfScreenAToOwnMid = sqrt(
                    pow(screenA.frame.midX - ownMid.x, 2) + pow(screenA.frame.midY - ownMid.y, 2)
                )
                let distanceOfScreenBToOwnMid = sqrt(
                    pow(screenB.frame.midX - ownMid.x, 2) + pow(screenB.frame.midY - ownMid.y, 2)
                )
                return distanceOfScreenAToOwnMid < distanceOfScreenBToOwnMid
            }.first
    }

    /// Locates a neighbour alongside a *compass* (rotated by 90 degrees) at the given angle in degrees, where a value ...
    ///
    /// - ... of 90 degrees points to the display directly above,
    /// - ... of 180 degrees points to the display directly to the left,
    /// - ... of 270 degrees points to the display directly below,
    /// - ... of 0 or 360 degrees points to the display to the right
    ///
    /// Intermediate values are valid as well.
    func findScreenAtAngle(degrees: UInt16) -> This? {
        return findScreenAtAngle(degrees: Double(degrees))
    }

    var neighbours: [This: AngleRange] {
        var result = [This: AngleRange]()

        for angle: UInt16 in 0 ... 360 {
            guard let otherScreen = findScreenAtAngle(degrees: angle) else {
                continue
            }
            var resultEntry = result[otherScreen] ?? (start: angle, end: angle)
            guard result[otherScreen] != nil else {
                result[otherScreen] = resultEntry
                continue
            }
            if resultEntry.start > resultEntry.end {
                continue
            }
            if angle - resultEntry.end > 1 {
                resultEntry = (start: angle, end: resultEntry.end)
                result[otherScreen] = resultEntry
                continue
            }
            result[otherScreen] = (start: resultEntry.start, end: angle)
        }

        return result
    }

    /// Locates a neighbour alongside a *compass* (rotated by 90 degrees) between the given angles in degrees, where a value ...
    ///
    /// - ... of 90 degrees points to the display directly above,
    /// - ... of 180 degrees points to the display directly to the left,
    /// - ... of 270 degrees points to the display directly below,
    /// - ... of 0 or 360 degrees points to the display to the right
    ///
    /// Intermediate values are valid as well.
    ///
    /// - returns: The screen with the longest shared edge *'real estate'*
    func findScreenBetween(alpha: UInt16, andBeta beta: UInt16) -> This? {
        findScreensBetween(alpha: alpha, andBeta: beta).first
    }

    /// Locates all neighbours alongside a *compass* (rotated by 90 degrees) between the given angles in degrees, where a value ...
    ///
    /// - ... of 90 degrees points to the display directly above,
    /// - ... of 180 degrees points to the display directly to the left,
    /// - ... of 270 degrees points to the display directly below,
    /// - ... of 0 or 360 degrees points to the display to the right
    ///
    /// Intermediate values are valid as well.
    func findScreensBetween(alpha: UInt16, andBeta beta: UInt16) -> [This] {
        let rangeBetweenAlphaAndBeta = alpha > beta
            ? (alpha ... 360).map(\.self) + (0 ... beta).map(\.self)
            : (alpha ... beta).map(\.self)
        typealias SequenceElement = (key: Self.This, value: AngleRange)
        return neighbours
            .filter { (pair: SequenceElement) -> Bool in
                let value = pair.value
                let isCounterClockwise = value.start > value.end
                return !(isCounterClockwise
                    ? (value.start ... 360).map(\.self) + (0 ... value.end)
                    : (min(value.start, value.end) ... max(value.end, value.start)).map(\.self)
                ).filter {
                    rangeBetweenAlphaAndBeta.contains($0)
                }.isEmpty
            }.sorted { (a: SequenceElement, b: SequenceElement) -> Bool in
                let isRangeOfScreenACounterClockwise = a.value.start > a.value.end
                let isRangeOfScreenBCounterClockwise = b.value.start > b.value.end

                let rangeOfScreenA = isRangeOfScreenACounterClockwise
                    ? (a.value.start ... 360).map(\.self) + (0 ... a.value.end)
                    : (min(a.value.start, a.value.end) ... max(a.value.end, a.value.start)).map(\.self)
                let rangeOfScreenB = isRangeOfScreenBCounterClockwise
                    ? (b.value.start ... 360).map(\.self) + (0 ... b.value.end)
                    : (min(b.value.start, b.value.end) ... max(b.value.end, b.value.start)).map(\.self)

                let isRangeSupersetOfScreenA = Set(rangeBetweenAlphaAndBeta).isSuperset(of: rangeOfScreenA)
                let isRangeSupersetOfScreenB = Set(rangeBetweenAlphaAndBeta).isSuperset(of: rangeOfScreenB)

                if isRangeSupersetOfScreenA != isRangeSupersetOfScreenB {
                    return isRangeSupersetOfScreenA
                }

                let matchesInScreenA = rangeOfScreenA.filter {
                    rangeBetweenAlphaAndBeta.contains($0)
                }
                let matchesInScreenB = rangeOfScreenB.filter {
                    rangeBetweenAlphaAndBeta.contains($0)
                }
                return matchesInScreenA.count > matchesInScreenB.count
            }.map(\.key)
    }
}

public extension Dictionary where Key: WindowContainer, Key: Hashable, Value == AngleRange {
    var withDistinctAngles: [Key: [UInt16]] {
        var result = [Key: [UInt16]]()
        for (key, value) in self {
            result[key] = [UInt16]()
            for angle in value.start ... value.end {
                result[key]?.append(angle)
            }
        }
        return result
    }
}
