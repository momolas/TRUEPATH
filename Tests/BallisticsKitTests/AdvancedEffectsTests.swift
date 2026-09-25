//
//  AdvancedEffectsTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func spinDriftCalculation() {
    // 175gr .308 projectile (diameter 0.308", length 1.24", 1:10" twist)
    let sg = SpinDrift.stabilityFactor(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches),
        length: Measurement(value: 1.24, unit: .inches),
        twist: Measurement(value: 10, unit: .inches),
        muzzleVelocity: Measurement(value: 2600, unit: .feetPerSecond)
    )

    // Sg should typically be around 1.5 - 2.6 for standard .308 175gr in 1:10 twist
    #expect(sg > 1.3 && sg < 3.0)

    // Spin drift for 1.0 second flight time (approx 600-700 yards)
    let rightDrift = SpinDrift.deflection(
        timeOfFlight: Measurement(value: 1.0, unit: .seconds),
        stabilityFactor: sg,
        twistDirection: .right
    )

    let leftDrift = SpinDrift.deflection(
        timeOfFlight: Measurement(value: 1.0, unit: .seconds),
        stabilityFactor: sg,
        twistDirection: .left
    )

    #expect(rightDrift.converted(to: .inches).value > 0)
    #expect(leftDrift.converted(to: .inches).value < 0)
    #expect(abs(rightDrift.converted(to: .inches).value + leftDrift.converted(to: .inches).value) < 1e-6)

    // At 1.0s, deflection is around 3.5 - 4.5 inches
    #expect(rightDrift.converted(to: .inches).value > 2.0 && rightDrift.converted(to: .inches).value < 6.0)
}

@Test func coriolisCalculation() {
    // Shooting at 45° North Latitude, East (90° Azimuth), 1000 yards (3000 ft), 1.5s time of flight
    let coriolis = Coriolis.deflection(
        latitude: Measurement(value: 45, unit: .degrees),
        azimuth: Measurement(value: 90, unit: .degrees),
        range: Measurement(value: 1000, unit: .yards),
        timeOfFlight: Measurement(value: 1.5, unit: .seconds)
    )

    // In Northern hemisphere (latitude > 0), horizontal Coriolis drift is positive (to the right)
    #expect(coriolis.horizontal.converted(to: .inches).value > 0)

    // Shooting East (azimuth = 90°), Eötvös effect causes bullet to hit high (positive vertical deflection)
    #expect(coriolis.vertical.converted(to: .inches).value > 0)

    // Shooting West (azimuth = 270°), Eötvös effect causes bullet to hit low (negative vertical deflection)
    let coriolisWest = Coriolis.deflection(
        latitude: Measurement(value: 45, unit: .degrees),
        azimuth: Measurement(value: 270, unit: .degrees),
        range: Measurement(value: 1000, unit: .yards),
        timeOfFlight: Measurement(value: 1.5, unit: .seconds)
    )

    #expect(coriolisWest.vertical.converted(to: .inches).value < 0)
}

@Test func integratedTrajectoryEffects() throws {
    let solution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: 0.250,
        initialVelocity: Measurement(value: 2700, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 10, unit: .milesPerHour),
        windAngle: 90,
        weight: Measurement(value: 175, unit: .grains),
        distanceStep: Measurement(value: 100, unit: .yards),
        twist: Measurement(value: 10, unit: .inches),
        twistDirection: .right,
        bulletDiameter: Measurement(value: 0.308, unit: .inches),
        bulletLength: Measurement(value: 1.24, unit: .inches),
        latitude: Measurement(value: 45, unit: .degrees),
        azimuth: Measurement(value: 90, unit: .degrees)
    )

    let point800 = try #require(solution.getPoint(at: Measurement(value: 800, unit: .yards)))

    // Check that advanced components are populated
    let spin = try #require(point800.spinDrift)
    let corHoriz = try #require(point800.coriolisHorizontal)
    let corVert = try #require(point800.coriolisVertical)

    #expect(spin.converted(to: .inches).value > 0)
    #expect(corHoriz.converted(to: .inches).value > 0)
    #expect(corVert.converted(to: .inches).value > 0)

    // Total windage should equal windage + spinDrift + coriolisHorizontal
    let expectedTotal = point800.windage.converted(to: .inches).value + spin.converted(to: .inches).value + corHoriz.converted(to: .inches).value
    #expect(abs(point800.totalWindage.converted(to: .inches).value - expectedTotal) < 1e-5)
}

@Test func sectionalDensityAndFormFactor() {
    // Standard .308 175gr bullet: SD = 175 / (7000 * 0.308^2) ≈ 0.2635
    let sd = SectionalDensity.calculate(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches)
    )
    #expect(abs(sd - 0.2635) < 0.001)

    // If G1 BC = 0.505, form factor i1 = SD / BC = 0.2635 / 0.505 ≈ 0.5218
    let i1 = SectionalDensity.formFactor(sectionalDensity: sd, ballisticCoefficient: 0.505)
    #expect(abs(i1 - 0.5218) < 0.005)

    // Reconstruct BC from SD and i
    let reconstructedBC = SectionalDensity.ballisticCoefficient(sectionalDensity: sd, formFactor: i1)
    #expect(abs(reconstructedBC - 0.505) < 1e-4)
}

@Test func atmosphereSpeedOfSound() {
    let standardAtmosphere = Atmosphere(
        temperature: Measurement(value: 59, unit: .fahrenheit)
    )
    let standardSpeed = standardAtmosphere.speedOfSound.converted(to: .feetPerSecond).value
    #expect(abs(standardSpeed - 1116.45) < 1.0)

    let coldAtmosphere = Atmosphere(
        temperature: Measurement(value: 0, unit: .fahrenheit)
    )
    let coldSpeed = coldAtmosphere.speedOfSound.converted(to: .feetPerSecond).value
    #expect(coldSpeed < 1060.0 && coldSpeed > 1040.0)
}
