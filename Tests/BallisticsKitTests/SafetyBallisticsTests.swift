//
//  SafetyBallisticsTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 09/10/2026.
//

import Testing
import Foundation
@testable import BallisticsKit

struct SafetyBallisticsTests {

    @Test
    func testRicochetEvaluation() {
        // Shallow 3° impact on water -> should ricochet with ~70% velocity
        let waterAngle = Measurement(value: 3.0, unit: UnitAngle.degrees)
        let v0 = Measurement(value: 2000, unit: UnitSpeed.feetPerSecond)
        let waterRes = SafetyBallistics.evaluateRicochet(
            impactAngle: waterAngle,
            impactVelocity: v0,
            surface: .water
        )
        #expect(waterRes.willRicochet)
        #expect(waterRes.residualVelocity.value > 1200)

        // Steep 30° impact on water -> no ricochet
        let steepAngle = Measurement(value: 30.0, unit: UnitAngle.degrees)
        let steepRes = SafetyBallistics.evaluateRicochet(
            impactAngle: steepAngle,
            impactVelocity: v0,
            surface: .water
        )
        #expect(steepRes.willRicochet == false)
        #expect(steepRes.residualVelocity.value == 0)

        // Hard ground with 8° angle -> should ricochet (crit is 15°)
        let groundAngle = Measurement(value: 8.0, unit: UnitAngle.degrees)
        let groundRes = SafetyBallistics.evaluateRicochet(
            impactAngle: groundAngle,
            impactVelocity: v0,
            surface: .hardGroundOrTurf
        )
        #expect(groundRes.willRicochet)
    }

    @Test
    func testDetailedRicochetEvaluationAndGuards() throws {
        let angle = Measurement(value: 5.0, unit: UnitAngle.degrees)
        let v = Measurement(value: 2500, unit: UnitSpeed.feetPerSecond)
        let detailed = SafetyBallistics.evaluateRicochetDetailed(impactAngle: angle, impactVelocity: v, surface: .hardGroundOrTurf)

        #expect(detailed.willRicochet)
        #expect(detailed.residualVelocity.converted(to: .feetPerSecond).value > 0)

        // Codable test
        let encoded = try JSONEncoder().encode(detailed)
        let decoded = try JSONDecoder().decode(SafetyBallistics.RicochetEvaluation.self, from: encoded)
        #expect(decoded == detailed)

        // Negative angle guard
        let negAngle = Measurement(value: -10.0, unit: UnitAngle.degrees)
        let negRes = SafetyBallistics.evaluateRicochetDetailed(impactAngle: negAngle, impactVelocity: v, surface: .hardGroundOrTurf)
        #expect(negRes.willRicochet == false)

        // Zero velocity guard
        let zeroV = Measurement(value: 0.0, unit: UnitSpeed.feetPerSecond)
        let zeroVRes = SafetyBallistics.evaluateRicochetDetailed(impactAngle: angle, impactVelocity: zeroV, surface: .hardGroundOrTurf)
        #expect(zeroVRes.willRicochet == false)
    }

    @Test
    func testMaximumRangeCalculation() {
        // .308 caliber bullet fired at 2650 fps
        let v0 = Measurement(value: 2650, unit: UnitSpeed.feetPerSecond)
        let result = SafetyBallistics.calculateMaximumRange(
            dragFunction: .g1,
            dragCoefficient: 0.450,
            initialVelocity: v0
        )

        // Maximum range in atmosphere for typical high power rifle bullet is between 3,000 and 6,000 yards (9,000 to 18,000 ft)
        let rangeYards = result.maximumRange.converted(to: .yards).value
        #expect(rangeYards > 2500)
        #expect(rangeYards < 7000)

        // Optimal aerodynamic launch angle should be between 30° and 38°
        let angleDeg = result.optimalLaunchAngle.converted(to: .degrees).value
        #expect(angleDeg >= 30.0 && angleDeg <= 38.0)

        // Apogee and flight time must be positive physical values
        #expect(result.vertexAltitude.converted(to: .feet).value > 1000)
        #expect(result.totalFlightTime.converted(to: .seconds).value > 15)
        #expect(result.terminalVelocity.converted(to: .feetPerSecond).value > 100)
    }
}
