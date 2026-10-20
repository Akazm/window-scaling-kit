import Foundation

public extension WindowTransitionController.Config {

    /// A spring animation, parameterized like SwiftUI's `Spring(duration:bounce:)`.
    ///
    /// `duration` is the perceptual duration in seconds, roughly the time the spring takes to settle.
    /// `bounce` ranges from `0`, a critically damped spring that never overshoots, upwards; values above
    /// `0.9` are clamped so that the spring always comes to rest. A bare number stands for a duration
    /// without bounce, which is also how plain animation durations were encoded before springs existed.
    struct Spring: Sendable, Hashable, Codable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {

        /// Settles in about a third of a second without overshoot, close to the system's own window
        /// animations.
        public static let `default` = Spring(duration: 0.3)
        /// For those who prefer windows to snap into place.
        public static let quick = Spring(duration: 0.25)

        /// The perceptual duration in seconds.
        public var duration: TimeInterval
        /// How much the spring overshoots, `0` for not at all.
        public var bounce: Double

        public init(duration: TimeInterval, bounce: Double = 0) {
            self.duration = max(duration, 0.001)
            self.bounce = min(max(bounce, 0), 0.9)
        }

        public init(floatLiteral value: Double) {
            self.init(duration: value)
        }

        public init(integerLiteral value: Int) {
            self.init(duration: TimeInterval(value))
        }

        private enum CodingKeys: String, CodingKey {
            case duration
            case bounce
        }

        public init(from decoder: any Decoder) throws {
            // Configs written before 1.5 hold the animation duration as a plain number.
            if let container = try? decoder.singleValueContainer(),
               let duration = try? container.decode(TimeInterval.self) {
                self.init(duration: duration)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                duration: try container.decode(TimeInterval.self, forKey: .duration),
                bounce: try container.decodeIfPresent(Double.self, forKey: .bounce) ?? 0
            )
        }
    }
}

/// One animated scalar: where it is and how fast it moves, in points and points per second.
struct SpringValue: Sendable, Hashable {
    var value: Double
    var velocity: Double = 0
}

extension WindowTransitionController.Config.Spring {

    /// The undamped angular frequency.
    var angularFrequency: Double {
        2 * .pi / duration
    }

    /// The damping ratio, where `1` is critically damped.
    var dampingRatio: Double {
        1 - bounce
    }

    /// Advances `state` by `dt` seconds towards `target`.
    ///
    /// Uses the closed-form solution of the spring equation, so the result is exact for any step size:
    /// a dropped frame simply moves further along the same curve. Retargeting needs no bookkeeping
    /// either, the next step just aims somewhere else while position and velocity carry over.
    func step(_ state: inout SpringValue, toward target: Double, dt: TimeInterval) {
        guard dt > 0 else {
            return
        }
        let omega = angularFrequency
        let zeta = dampingRatio
        let displacement = state.value - target
        let velocity = state.velocity
        if abs(zeta - 1) < 1e-3 {
            // Critically damped: x(t) = (a + b·t)·e^(−ω·t)
            let a = displacement
            let b = velocity + omega * displacement
            let decay = exp(-omega * dt)
            state.value = target + (a + b * dt) * decay
            state.velocity = (b - omega * (a + b * dt)) * decay
        } else {
            // Under-damped: x(t) = e^(−ζ·ω·t)·(a·cos(ωd·t) + b·sin(ωd·t))
            let dampedOmega = omega * (1 - zeta * zeta).squareRoot()
            let a = displacement
            let b = (velocity + zeta * omega * displacement) / dampedOmega
            let decay = exp(-zeta * omega * dt)
            let cosine = cos(dampedOmega * dt)
            let sine = sin(dampedOmega * dt)
            state.value = target + decay * (a * cosine + b * sine)
            state.velocity = decay * (
                (dampedOmega * b - zeta * omega * a) * cosine - (dampedOmega * a + zeta * omega * b) * sine
            )
        }
    }

    /// Whether `state` has come to rest at `target`: it is within half a point and stays there over the
    /// next couple of frames, which a bouncy spring passing through the target does not.
    func isSettled(_ state: SpringValue, at target: Double) -> Bool {
        guard abs(state.value - target) < 0.5 else {
            return false
        }
        var ahead = state
        step(&ahead, toward: target, dt: 2.0 / 60.0)
        return abs(ahead.value - target) < 0.5
    }
}
