//
//  AdaptiveIntegratorTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 02/10/2026.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func dormandPrinceButcherTableauIntegrity() {
    // 5th-order weights sum must equal 1.0
    let bSum = DormandPrince54.b1 + DormandPrince54.b2 + DormandPrince54.b3 + DormandPrince54.b4 + DormandPrince54.b5 + DormandPrince54.b6 + DormandPrince54.b7
    #expect(abs(bSum - 1.0) < 1e-12)

    // Error weights sum must equal 0.0 (since b and b_hat both sum to 1.0)
    let eSum = DormandPrince54.e1 + DormandPrince54.e2 + DormandPrince54.e3 + DormandPrince54.e4 + DormandPrince54.e5 + DormandPrince54.e6 + DormandPrince54.e7
    #expect(abs(eSum) < 1e-12)
}

@Test func adaptiveIntegratorPrecisionComparison() throws {
    let bullet = BulletCatalog.sierraMatchKing308_175gr
    let props = bullet.projectileProperties()

    // Run standard tolerance simulation
    let solutionStandard = Ballistics.solve(
        properties: props,
        dragFunction: .g7,
        dragCoefficient: bullet.bcG7 ?? 0.243,
        initialVelocity: Measurement(value: 2650, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        twist: Measurement(value: 10, unit: .inches),
        twistDirection: .right,
        distanceStep: Measurement(value: 100, unit: .yards),
        tolerance: .standard,
        maxRange: Measurement(value: 800, unit: .yards)
    )

    // Run high precision tolerance simulation
    let solutionHighPrecision = Ballistics.solve(
        properties: props,
        dragFunction: .g7,
        dragCoefficient: bullet.bcG7 ?? 0.243,
        initialVelocity: Measurement(value: 2650, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        twist: Measurement(value: 10, unit: .inches),
        twistDirection: .right,
        distanceStep: Measurement(value: 100, unit: .yards),
        tolerance: .highPrecision,
        maxRange: Measurement(value: 800, unit: .yards)
    )

    let pointStd600 = try #require(solutionStandard.getPoint(at: Measurement(value: 600, unit: .yards)))
    let pointHigh600 = try #require(solutionHighPrecision.getPoint(at: Measurement(value: 600, unit: .yards)))

    // Drop and windage between standard and high-precision should match within 0.1 inch at 600 yards
    let dropStd = pointStd600.drop.converted(to: .inches).value
    let dropHigh = pointHigh600.drop.converted(to: .inches).value
    #expect(abs(dropStd - dropHigh) < 0.1)

    // Velocity should match within 0.5 fps
    let vStd = pointStd600.velocity.converted(to: .feetPerSecond).value
    let vHigh = pointHigh600.velocity.converted(to: .feetPerSecond).value
    #expect(abs(vStd - vHigh) < 0.5)

    // Dynamic stability and spin rate should be physically consistent
    #expect(pointStd600.spinRateRPM ?? 0 > 100000)
    #expect(pointStd600.stabilityFactorSg ?? 0 > 1.2)
}
