import Foundation

extension Double {
    var decimal: Decimal {
        return Decimal(self)
    }
}

extension Float {
    var decimal: Decimal {
        return Double(self).decimal
    }
}

extension CGFloat {
    var decimal: Decimal {
        return Double(self).decimal
    }
}

extension Decimal {
    func rounded(scale: Int, roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, roundingMode)
        return result
    }

    var cgFloat: CGFloat {
        return CGFloat(NSDecimalNumber(decimal: self).doubleValue)
    }
}

extension CGFloat {
    init(_ decimal: Decimal) {
        self.init(NSDecimalNumber(decimal: decimal).doubleValue)
    }
}
