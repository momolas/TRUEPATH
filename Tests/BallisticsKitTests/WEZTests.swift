//
//  WEZTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 09/10/2026.
//

import Testing
import Foundation
@testable import BallisticsKit

struct WEZTests {

    @Test
    func testTargetGeometryContainment() {
        // Circle 10 inches diameter (radius 5 inches)
        let circle = TargetGeometry.circle(diameter: Measurement(value: 10, unit: .inches))
        #expect(circle.contains(horizontal: Measurement(value: 3, unit: .inches), vertical: Measurement(value: 3, unit: .inches)))
        #expect(!circle.contains(horizontal: Measurement(value: 6, unit: .inches), vertical: Measurement(value: 0, unit: .inches)))

        // Rectangle 12 x 18 inches (half width 6, half height 9)
        let rect = TargetGeometry.rectangle(
            width: Measurement(value: 12, unit: .inches),
            height: Measurement(value: 18, unit: .inches)
        )
        #expect(rect.contains(horizontal: Measurement(value: 5.5, unit: .inches), vertical: Measurement(value: 8.5, unit: .inches)))
        #expect(!rect.contains(horizontal: Measurement(value: 6.5, unit: .inches), vertical: Measurement(value: 8.5, unit: .inches)))

        // NATO Type E silhouette
        let nato = TargetGeometry.natoSilhouette(type: .typeE)
        #expect(nato.contains(horizontal: Measurement(value: 8, unit: .inches), vertical: Measurement(value: 15, unit: .inches)))
        #expect(!nato.contains(horizontal: Measurement(value: 12, unit: .inches), vertical: Measurement(value: 0, unit: .inches)))
    }

    @Test
    func testMonteCarloHitProbabilityCalculation() {
        let dispersion = MonteCarloDispersion(
            muzzleVelocitySD: Measurement(value: 8, unit: .feetPerSecond),
            windSpeedSD: Measurement(value: 1.0, unit: .milesPerHour),
            shooterAngularSD: Measurement(value: 0.25, unit: .minutesOfAngle)
        )

        let result = MonteCarlo.simulate(
            shotCount: 60,
            targetDistance: Measurement(value: 300, unit: .yards),
            dispersion: dispersion,
            dragFunction: .g7,
            dragCoefficient: 0.265,
            nominalVelocity: Measurement(value: 2750, unit: .feetPerSecond),
            sightHeight: Measurement(value: 1.5, unit: .inches),
            zeroRange: Measurement(value: 100, unit: .yards),
            randomSeed: 12345
        )

        // On a large 30-inch target at 300 yards with match ammo, hit rate should be very high (>= 90%)
        let largeTarget = TargetGeometry.circle(diameter: Measurement(value: 30, unit: .inches))
        let probLarge = result.hitProbability(for: largeTarget)
        #expect(probLarge >= 90.0)

        // On a tiny 2-inch target at 300 yards, hit rate should be lower
        let tinyTarget = TargetGeometry.circle(diameter: Measurement(value: 2, unit: .inches))
        let probTiny = result.hitProbability(for: tinyTarget)
        #expect(probTiny <= probLarge)
    }

    @Test
    func testWEZAnalysisSensitivity() {
        let target = TargetGeometry.rectangle(
            width: Measurement(value: 16, unit: .inches),
            height: Measurement(value: 24, unit: .inches)
        )

        let analysis = WEZAnalysis.analyze(
            shotCount: 50,
            targetDistance: Measurement(value: 500, unit: .yards),
            target: target,
            dragFunction: .g7,
            dragCoefficient: 0.280,
            nominalVelocity: Measurement(value: 2700, unit: .feetPerSecond),
            sightHeight: Measurement(value: 1.5, unit: .inches),
            zeroRange: Measurement(value: 100, unit: .yards),
            nominalWindSpeed: Measurement(value: 8, unit: .milesPerHour),
            randomSeed: 999
        )

        #expect(analysis.baselineHitProbability > 0.0)
        #expect(!analysis.primaryLimitingFactor.isEmpty)
    }
}
