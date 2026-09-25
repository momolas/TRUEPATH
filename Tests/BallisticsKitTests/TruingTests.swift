//
//  TruingTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func muzzleVelocityTruing() throws {
    // 1. Forward simulation with known true V0 = 2650 fps at 500 yards
    let trueV0 = Measurement(value: 2650.0, unit: UnitSpeed.feetPerSecond)
    let sightH = Measurement(value: 1.5, unit: UnitLength.inches)
    let zeroR = Measurement(value: 100.0, unit: UnitLength.yards)
    let targetDist = Measurement(value: 500.0, unit: UnitLength.yards)
    let trueBC = 0.450

    let forwardSolution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g1,
        dragCoefficient: trueBC,
        initialVelocity: trueV0,
        sightHeight: sightH,
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: zeroR,
        windSpeed: Measurement(value: 0, unit: .milesPerHour),
        windAngle: 0,
        weight: Measurement(value: 175, unit: .grains),
        distanceStep: Measurement(value: 10, unit: .yards)
    )

    let point500 = try #require(forwardSolution.getPoint(at: targetDist))
    let observedCorrection = point500.dropCorrection

    // 2. Perform V0 Truing starting from an erroneous initial guess of 2900 fps
    let truingResult = Truing.calibrateMuzzleVelocity(
        observedDropCorrection: observedCorrection,
        atDistance: targetDist,
        dragFunction: .g1,
        dragCoefficient: trueBC,
        sightHeight: sightH,
        zeroRange: zeroR,
        initialVelocityGuess: Measurement(value: 2900, unit: .feetPerSecond),
        weight: Measurement(value: 175, unit: .grains)
    )

    switch truingResult {
    case .success(let calibratedV0):
        let calFPS = calibratedV0.converted(to: .feetPerSecond).value
        #expect(abs(calFPS - 2650.0) < 1.5)
    case .failure(let error):
        Issue.record("Muzzle velocity truing failed: \(error)")
    }
}

@Test func ballisticCoefficientTruing() throws {
    // 1. Forward simulation with known true BC = 0.535 at 900 yards
    let knownV0 = Measurement(value: 2750.0, unit: UnitSpeed.feetPerSecond)
    let sightH = Measurement(value: 1.5, unit: UnitLength.inches)
    let zeroR = Measurement(value: 100.0, unit: UnitLength.yards)
    let targetDist = Measurement(value: 900.0, unit: UnitLength.yards)
    let trueBC = 0.535

    let forwardSolution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: trueBC,
        initialVelocity: knownV0,
        sightHeight: sightH,
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: zeroR,
        windSpeed: Measurement(value: 0, unit: .milesPerHour),
        windAngle: 0,
        weight: Measurement(value: 175, unit: .grains),
        distanceStep: Measurement(value: 10, unit: .yards)
    )

    let point900 = try #require(forwardSolution.getPoint(at: targetDist))
    let observedCorrection = point900.dropCorrection

    // 2. Perform BC Truing starting from an erroneous initial guess of 0.400
    let truingResult = Truing.calibrateBallisticCoefficient(
        observedDropCorrection: observedCorrection,
        atDistance: targetDist,
        muzzleVelocity: knownV0,
        dragFunction: .g7,
        sightHeight: sightH,
        zeroRange: zeroR,
        dragCoefficientGuess: 0.400,
        weight: Measurement(value: 175, unit: .grains)
    )

    switch truingResult {
    case .success(let calibratedBC):
        #expect(abs(calibratedBC - 0.535) < 0.005)
    case .failure(let error):
        Issue.record("BC truing failed: \(error)")
    }
}
