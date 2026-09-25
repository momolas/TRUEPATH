//
//  TurretAndRangingTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func turretClickConversions() {
    // 2.5 MOA drop correction with 1/4 MOA clicks -> 10 clicks
    let dropCorrectionMOA = Measurement(value: 2.5, unit: UnitAngle.minutesOfAngle)
    #expect(TurretClick.oneFourthMOA.clicks(for: dropCorrectionMOA) == 10)

    // 2.5 MOA drop correction with 1/8 MOA clicks -> 20 clicks
    #expect(TurretClick.oneEighthMOA.clicks(for: dropCorrectionMOA) == 20)

    // 1.2 MRAD correction with 0.1 MRAD clicks -> 12 clicks
    let correctionMIL = Measurement(value: 1.2, unit: UnitAngle.milliradians)
    #expect(TurretClick.pointOneMRAD.clicks(for: correctionMIL) == 12)

    // Point helpers
    let point = Point(
        range: Measurement(value: 500, unit: .yards),
        drop: Measurement(value: -50, unit: .inches),
        dropCorrection: Measurement(value: 9.55, unit: .minutesOfAngle),
        windage: Measurement(value: 15, unit: .inches),
        windageCorrection: Measurement(value: 2.86, unit: .minutesOfAngle),
        travelTime: Measurement(value: 0.6, unit: .seconds),
        velocity: Measurement(value: 2000, unit: .feetPerSecond),
        velocityX: Measurement(value: 1990, unit: .feetPerSecond),
        velocityY: Measurement(value: -150, unit: .feetPerSecond),
        energy: Measurement(value: 1500, unit: .footPounds)
    )

    #expect(point.elevationClicks(.oneFourthMOA) == 38) // 9.55 / 0.25 ≈ 38.2 -> 38
    #expect(point.windageClicks(.oneFourthMOA) == 11)   // 2.86 / 0.25 ≈ 11.44 -> 11
}

@Test func reticleRangingCalculations() {
    // Target of 0.5m (50cm) measured at 1.0 MIL -> 500 meters
    let targetHeight = Measurement(value: 0.5, unit: UnitLength.meters)
    let angleMIL = Measurement(value: 1.0, unit: UnitAngle.milliradians)

    let estimatedDist = Ranging.distance(targetSize: targetHeight, angularSize: angleMIL)
    #expect(abs(estimatedDist.converted(to: .meters).value - 500.0) < 0.5)

    // Subtension of 1m target at 1000m is 1 MIL
    let subtension = Ranging.subtension(
        targetSize: Measurement(value: 1.0, unit: .meters),
        distance: Measurement(value: 1000.0, unit: .meters)
    )
    #expect(abs(subtension.converted(to: .milliradians).value - 1.0) < 0.01)

    // Target size of 2 MIL at 400m is 0.8m (80cm)
    let size = Ranging.targetSize(
        distance: Measurement(value: 400, unit: .meters),
        angularSize: Measurement(value: 2.0, unit: .milliradians)
    )
    #expect(abs(size.converted(to: .meters).value - 0.8) < 0.01)
}
