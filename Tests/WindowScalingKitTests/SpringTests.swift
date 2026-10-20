import Foundation
import Testing
@testable import WindowScalingKit

private typealias Spring = WindowTransitionController.Config.Spring

@Suite struct SpringTests {

    @Test func criticallyDampedSpringApproachesMonotonicallyWithoutOvershoot() {
        let spring = Spring(duration: 0.3)
        var state = SpringValue(value: 0)
        var previous = 0.0
        for _ in 0 ..< 120 {
            spring.step(&state, toward: 200, dt: 1.0 / 60.0)
            #expect(state.value <= 200 + 1e-9)
            #expect(state.value >= previous - 1e-9)
            previous = state.value
        }
        #expect(abs(state.value - 200) < 1e-6)
    }

    @Test func settlesInRoughlyItsDuration() {
        let spring = Spring(duration: 0.3)
        var state = SpringValue(value: 0)
        var elapsed = 0.0
        while !spring.isSettled(state, at: 200) {
            spring.step(&state, toward: 200, dt: 1.0 / 120.0)
            elapsed += 1.0 / 120.0
            #expect(elapsed < 1)
        }
        #expect(elapsed > 0.25)
        #expect(elapsed < 0.45)
    }

    @Test func stepIsIndependentOfFrameRate() {
        for bounce in [0.0, 0.15, 0.5] {
            let spring = Spring(duration: 0.3, bounce: bounce)
            var coarse = SpringValue(value: 0, velocity: 500)
            var fine = coarse
            spring.step(&coarse, toward: 200, dt: 0.032)
            spring.step(&fine, toward: 200, dt: 0.016)
            spring.step(&fine, toward: 200, dt: 0.016)
            #expect(abs(coarse.value - fine.value) < 1e-9)
            #expect(abs(coarse.velocity - fine.velocity) < 1e-9)
        }
    }

    @Test func momentumCarriesAcrossARetarget() {
        let spring = Spring(duration: 0.3)
        var state = SpringValue(value: 0)
        for _ in 0 ..< 6 {
            spring.step(&state, toward: 200, dt: 1.0 / 60.0)
        }
        let velocityBefore = state.velocity
        #expect(velocityBefore > 0)
        // Retargeting only changes where the next step aims; position and velocity are continuous.
        var retargeted = state
        spring.step(&retargeted, toward: 400, dt: 1e-6)
        #expect(abs(retargeted.velocity - velocityBefore) < 1)
        #expect(abs(retargeted.value - state.value) < 0.01)
    }

    @Test func bouncySpringIsNotSettledWhilePassingThroughTheTarget() {
        let spring = Spring(duration: 0.3, bounce: 0.5)
        #expect(!spring.isSettled(SpringValue(value: 200.1, velocity: 2000), at: 200))
        #expect(spring.isSettled(SpringValue(value: 200.1, velocity: 0), at: 200))
    }

    @Test func decodesPlainDurationsFromOlderConfigs() throws {
        let legacy = Data(#"{"auto":{"_0":0.1163}}"#.utf8)
        let decoded = try JSONDecoder().decode(
            WindowTransitionController.Config.DisableAnimation.self, from: legacy
        )
        #expect(decoded == .auto(Spring(duration: 0.1163)))
        let spring = Spring(duration: 0.3, bounce: 0.1)
        let roundTrip = try JSONDecoder().decode(Spring.self, from: JSONEncoder().encode(spring))
        #expect(roundTrip == spring)
    }

    @Test func literalsAreDurations() {
        let spring: Spring = 0.25
        #expect(spring == Spring(duration: 0.25))
        #expect(spring.bounce == 0)
    }
}
