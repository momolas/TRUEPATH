//
//  MonteCarloTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 20/09/2026.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func monteCarloSimulationStatistics() {
    // Simulate 150 shots at 600 yards with typical match ammo dispersion
    let dispersion = MonteCarloDispersion(
        muzzleVelocitySD: Measurement(value: 12, unit: .feetPerSecond),
        windSpeedSD: Measurement(value: 2.0, unit: .milesPerHour),
        shooterAngularSD: Measurement(value: 0.35, unit: .minutesOfAngle)
    )

    let result = MonteCarlo.simulate(
        shotCount: 150,
        targetDistance: Measurement(value: 600, unit: .yards),
        dispersion: dispersion,
        dragFunction: .g7,
        dragCoefficient: 0.265,
        nominalVelocity: Measurement(value: 2750, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        nominalWindSpeed: Measurement(value: 10, unit: .milesPerHour),
        nominalWindAngle: 90,
        weight: Measurement(value: 175, unit: .grains),
        randomSeed: 42
    )

    // Verify sample count
    #expect(result.sampleCount == 150)
    #expect(result.shots.count == 150)

    // Statistical sanity checks
    // Vertical and horizontal standard deviations must be positive and realistic (< 15 inches at 600 yds)
    #expect(result.horizontalSD.value > 0.5)
    #expect(result.horizontalSD.value < 20.0)
    #expect(result.verticalSD.value > 0.5)
    #expect(result.verticalSD.value < 20.0)

    // Extreme spread must be greater than standard deviation
    #expect(result.extremeSpreadHorizontal.value > result.horizontalSD.value)
    #expect(result.extremeSpreadVertical.value > result.verticalSD.value)

    // CEP 50% must be smaller than R95
    #expect(result.cep50.value > 0)
    #expect(result.r95.value > result.cep50.value)

    // Terminal velocity must be positive and lower than muzzle velocity (subsonic or supersonic)
    #expect(result.meanTerminalVelocity.value > 1200)
    #expect(result.meanTerminalVelocity.value < 2750)
    #expect(result.terminalVelocitySD.value > 0)

    // Terminal energy must be positive
    #expect(result.meanTerminalEnergy.value > 500)
}

@Test func monteCarloDeterministicSeed() {
    let dispersion = MonteCarloDispersion(
        muzzleVelocitySD: Measurement(value: 10, unit: .feetPerSecond),
        windSpeedSD: Measurement(value: 1, unit: .milesPerHour),
        shooterAngularSD: Measurement(value: 0.2, unit: .minutesOfAngle)
    )

    let r1 = MonteCarlo.simulate(
        shotCount: 50,
        targetDistance: Measurement(value: 400, unit: .yards),
        dispersion: dispersion,
        dragFunction: .g1,
        dragCoefficient: 0.450,
        nominalVelocity: Measurement(value: 2800, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        randomSeed: 9999
    )

    let r2 = MonteCarlo.simulate(
        shotCount: 50,
        targetDistance: Measurement(value: 400, unit: .yards),
        dispersion: dispersion,
        dragFunction: .g1,
        dragCoefficient: 0.450,
        nominalVelocity: Measurement(value: 2800, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        randomSeed: 9999
    )

    // With identical seed, outputs should be strictly equal
    #expect(abs(r1.meanHorizontalDeviation.value - r2.meanHorizontalDeviation.value) < 1e-9)
    #expect(abs(r1.meanVerticalDeviation.value - r2.meanVerticalDeviation.value) < 1e-9)
    #expect(abs(r1.horizontalSD.value - r2.horizontalSD.value) < 1e-9)
    #expect(abs(r1.verticalSD.value - r2.verticalSD.value) < 1e-9)
    #expect(abs(r1.cep50.value - r2.cep50.value) < 1e-9)
}
