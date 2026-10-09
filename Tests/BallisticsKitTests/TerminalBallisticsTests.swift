//
//  TerminalBallisticsTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 09/10/2026.
//

import Testing
import Foundation
@testable import BallisticsKit

struct TerminalBallisticsTests {

    @Test
    func testMatunasOptimalGameWeight() {
        // .308 Winchester 175gr at 2600 fps:
        // OGW = (2600^3 * 175^2) / 1.5e12 = (17576000000 * 30625) / 1.5e12 ≈ 358.8 lbs
        let v = Measurement(value: 2600, unit: UnitSpeed.feetPerSecond)
        let w = Measurement(value: 175, unit: UnitMass.grains)

        let ogw = TerminalBallistics.optimalGameWeight(velocity: v, bulletWeight: w)
        #expect(ogw.converted(to: .pounds).value > 300.0)
        #expect(ogw.converted(to: .pounds).value < 400.0)
    }

    @Test
    func testTaylorKnockoutFactor() {
        // .308 175gr at 2600 fps: TKOF = (175 * 2600 * 0.308) / 7000 ≈ 20.02
        let v = Measurement(value: 2600, unit: UnitSpeed.feetPerSecond)
        let w = Measurement(value: 175, unit: UnitMass.grains)
        let d = Measurement(value: 0.308, unit: UnitLength.inches)

        let tkof = TerminalBallistics.taylorKnockoutFactor(velocity: v, bulletWeight: w, bulletDiameter: d)
        #expect(abs(tkof - 20.02) < 0.2)
    }

    @Test
    func testExpansionThreshold() {
        let vSupersonic = Measurement(value: 2100, unit: UnitSpeed.feetPerSecond)
        let vSubsonic = Measurement(value: 1050, unit: UnitSpeed.feetPerSecond)

        #expect(TerminalBallistics.isAboveExpansionThreshold(impactVelocity: vSupersonic))
        #expect(!TerminalBallistics.isAboveExpansionThreshold(impactVelocity: vSubsonic))
    }

    @Test
    func testPointTerminalMetrics() {
        let point = Point(
            range: Measurement(value: 400, unit: .yards),
            drop: Measurement(value: -30, unit: .inches),
            dropCorrection: Measurement(value: 7.0, unit: .minutesOfAngle),
            windage: Measurement(value: 5, unit: .inches),
            windageCorrection: Measurement(value: 1.2, unit: .minutesOfAngle),
            travelTime: Measurement(value: 0.5, unit: .seconds),
            velocity: Measurement(value: 2200, unit: .feetPerSecond),
            velocityX: Measurement(value: 2190, unit: .feetPerSecond),
            velocityY: Measurement(value: -10, unit: .feetPerSecond),
            energy: Measurement(value: 1900, unit: .footPounds)
        )

        let weight = Measurement(value: 168, unit: UnitMass.grains)
        let diam = Measurement(value: 0.308, unit: UnitLength.inches)

        let ogw = point.optimalGameWeight(bulletWeight: weight)
        let tkof = point.taylorKnockoutFactor(bulletWeight: weight, bulletDiameter: diam)

        #expect(ogw.converted(to: .pounds).value > 150.0)
        #expect(tkof > 10.0)
    }
}
