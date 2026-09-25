//
//  ExtremeLongRangeTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func dangerSpaceCalculation() throws {
    let solution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: 0.250,
        initialVelocity: Measurement(value: 2700, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 0, unit: .milesPerHour),
        windAngle: 0,
        weight: Measurement(value: 175, unit: .grains),
        distanceStep: Measurement(value: 10, unit: .yards)
    )

    let danger = DangerSpace.calculate(
        solution: solution,
        targetDistance: Measurement(value: 600, unit: .yards),
        targetHeight: Measurement(value: 20, unit: .inches) // 20 inch target
    )

    let nearYards = danger.nearBound.converted(to: .yards).value
    let farYards = danger.farBound.converted(to: .yards).value

    #expect(nearYards < 600.0)
    #expect(farYards > 600.0)
    #expect(danger.totalDepth.converted(to: .yards).value > 0)
}

@Test func powderSensitivity() {
    // 2700 fps at 59°F, sensitivity 1.5 fps/°F
    let vBase = Measurement(value: 2700, unit: UnitSpeed.feetPerSecond)
    let tBase = Measurement(value: 59, unit: UnitTemperature.fahrenheit)
    let tHot = Measurement(value: 99, unit: UnitTemperature.fahrenheit) // +40°F

    let vHot = PowderSensitivity.adjustedVelocity(
        baseVelocity: vBase,
        baseTemperature: tBase,
        currentTemperature: tHot,
        sensitivityFPSPerDegreeF: 1.5
    )

    // Expected: 2700 + 1.5 * 40 = 2760 fps
    #expect(abs(vHot.converted(to: .feetPerSecond).value - 2760.0) < 0.1)

    // Reverse sensitivity calculation
    let calculatedSens = PowderSensitivity.calculateSensitivity(
        velocity1: vBase,
        temperature1: tBase,
        velocity2: vHot,
        temperature2: tHot
    )
    #expect(abs(calculatedSens - 1.5) < 0.001)
}

@Test func aerodynamicJump() {
    // 10 mph crosswind, 3000 fps, right twist
    let jumpRight = AerodynamicJump.jumpAngle(
        crosswindSpeed: Measurement(value: 10, unit: .milesPerHour),
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        twistDirection: .right
    )
    #expect(jumpRight.converted(to: .minutesOfAngle).value > 0)

    let jumpLeft = AerodynamicJump.jumpAngle(
        crosswindSpeed: Measurement(value: 10, unit: .milesPerHour),
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        twistDirection: .left
    )
    #expect(jumpLeft.converted(to: .minutesOfAngle).value < 0)
}

@Test func customDragModelAndMachRegimes() {
    let cdm = CustomDragModel(dataPoints: [
        .init(mach: 0.5, cd: 0.15),
        .init(mach: 1.0, cd: 0.40),
        .init(mach: 1.5, cd: 0.35),
        .init(mach: 2.0, cd: 0.30)
    ])

    #expect(abs(cdm.dragCoefficient(atMach: 0.5) - 0.15) < 1e-4)
    #expect(abs(cdm.dragCoefficient(atMach: 1.0) - 0.40) < 1e-4)
    #expect(abs(cdm.dragCoefficient(atMach: 0.75) - 0.275) < 1e-4) // Linear midpoint

    let retardVal = cdm.retard(ballisticCoefficient: 1.0, projectileVelocity: 2232.9) // Mach 2.0
    #expect(retardVal > 0)

    // Flight regimes check on Point
    let pointSuper = Point(
        range: Measurement(value: 100, unit: .yards),
        drop: Measurement(value: 0, unit: .inches),
        dropCorrection: Measurement(value: 0, unit: .minutesOfAngle),
        windage: Measurement(value: 0, unit: .inches),
        windageCorrection: Measurement(value: 0, unit: .minutesOfAngle),
        travelTime: Measurement(value: 0.1, unit: .seconds),
        velocity: Measurement(value: 2800, unit: .feetPerSecond), // ~Mach 2.5
        velocityX: Measurement(value: 2800, unit: .feetPerSecond),
        velocityY: Measurement(value: 0, unit: .feetPerSecond),
        energy: Measurement(value: 2000, unit: .footPounds)
    )
    #expect(pointSuper.isSupersonic())
    #expect(!pointSuper.isTransonic())
    #expect(!pointSuper.isSubsonic())

    let pointTrans = Point(
        range: Measurement(value: 800, unit: .yards),
        drop: Measurement(value: -150, unit: .inches),
        dropCorrection: Measurement(value: 18, unit: .minutesOfAngle),
        windage: Measurement(value: 20, unit: .inches),
        windageCorrection: Measurement(value: 2.5, unit: .minutesOfAngle),
        travelTime: Measurement(value: 1.2, unit: .seconds),
        velocity: Measurement(value: 1100, unit: .feetPerSecond), // ~Mach 0.98
        velocityX: Measurement(value: 1090, unit: .feetPerSecond),
        velocityY: Measurement(value: -100, unit: .feetPerSecond),
        energy: Measurement(value: 500, unit: .footPounds)
    )
    #expect(!pointTrans.isSupersonic())
    #expect(pointTrans.isTransonic())
    #expect(!pointTrans.isSubsonic())
}
