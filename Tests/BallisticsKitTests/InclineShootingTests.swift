//
//  InclineShootingTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func inclineShootingCalculations() {
    // 500m slant range at 30° incline -> 500 * cos(30°) = 500 * 0.866025 ≈ 433.01 meters
    let slantDist = Measurement(value: 500.0, unit: UnitLength.meters)
    let angle30Deg = Measurement(value: 30.0, unit: UnitAngle.degrees)

    let riflemanEquiv = InclineShooting.riflemanEquivalentRange(
        lineOfSightRange: slantDist,
        inclineAngle: angle30Deg
    )
    #expect(abs(riflemanEquiv.converted(to: .meters).value - 433.01) < 0.1)

    // Downhill (-30°) should yield the exact same cosine equivalent range
    let angleMinus30Deg = Measurement(value: -30.0, unit: UnitAngle.degrees)
    let riflemanDownhill = InclineShooting.riflemanEquivalentRange(
        lineOfSightRange: slantDist,
        inclineAngle: angleMinus30Deg
    )
    #expect(abs(riflemanDownhill.converted(to: .meters).value - 433.01) < 0.1)

    // Sierra improved rule should be slightly longer than Rifleman's rule at 30°
    let sierraEquiv = InclineShooting.sierraImprovedEquivalentRange(
        lineOfSightRange: slantDist,
        inclineAngle: angle30Deg,
        factor: 0.25
    )
    let sierraVal = sierraEquiv.converted(to: .meters).value
    #expect(sierraVal > 433.01 && sierraVal < 500.0)

    // CoreMotion pitch cosine factor
    let pitchRad = Double.pi / 6.0 // 30° in radians
    let cosVal = InclineShooting.cosineFactor(fromPitchRadians: pitchRad)
    #expect(abs(cosVal - 0.866025) < 0.001)
}
