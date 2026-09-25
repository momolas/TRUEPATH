//
//  Solver6DOFTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func projectilePropertiesCalculations() {
    // Standard .308 175gr Match projectile (diameter 0.308", length 1.24")
    let props = ProjectileProperties(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches),
        length: Measurement(value: 1.24, unit: .inches)
    )

    #expect(props.massSlugs > 0.0007 && props.massSlugs < 0.0009)
    #expect(props.referenceAreaSquareFeet > 0.0005 && props.referenceAreaSquareFeet < 0.0006)
    #expect(props.axialInertia > 0)
    #expect(props.transverseInertia > props.axialInertia) // Transverse inertia is much larger than axial for long bullets
}

@Test func aerodynamicCoefficientsSynthesis() {
    let props = ProjectileProperties(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches),
        length: Measurement(value: 1.24, unit: .inches)
    )

    let coeffs = AerodynamicCoefficients.synthesize(
        properties: props,
        dragFunction: .g7,
        dragCoefficient: 0.250
    )

    let cdSupersonic = coeffs.cd0(2.0)
    let cdSubsonic = coeffs.cd0(0.5)
    #expect(cdSupersonic > 0.10)
    #expect(cdSubsonic > 0.05)

    // Pitch damping and spin damping must be negative (damping forces)
    #expect(coeffs.cmq(2.0) < 0)
    #expect(coeffs.clp(2.0) < 0)
    #expect(coeffs.cmAlpha(2.0) > 0) // Overturning moment is positive
}

@Test func solver6DOFSimulation() throws {
    let props = ProjectileProperties(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches),
        length: Measurement(value: 1.24, unit: .inches)
    )

    let solution6DOF = Ballistics.solve6DOF(
        properties: props,
        dragFunction: .g7,
        dragCoefficient: 0.250,
        initialVelocity: Measurement(value: 2600, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        twist: Measurement(value: 10, unit: .inches),
        twistDirection: .right,
        distanceStep: Measurement(value: 100, unit: .yards)
    )

    #expect(!solution6DOF.distances.isEmpty)

    let point0 = try #require(solution6DOF.getPoint(at: Measurement(value: 0, unit: .yards)))
    let point500 = try #require(solution6DOF.getPoint(at: Measurement(value: 500, unit: .yards)))
    let point1000 = try #require(solution6DOF.getPoint(at: Measurement(value: 1000, unit: .yards)))

    // 1. Initial spin rate at muzzle: ~187,200 RPM for 2600 fps with 1:10" twist
    let initialRPM = try #require(point0.spinRateRPM)
    #expect(abs(initialRPM - 187200.0) < 1000.0)

    // 2. Spin decay: RPM must decrease over distance due to roll damping moment Clp
    let rpm500 = try #require(point500.spinRateRPM)
    let rpm1000 = try #require(point1000.spinRateRPM)
    #expect(rpm500 < initialRPM)
    #expect(rpm1000 < rpm500)
    #expect(rpm1000 > 120000.0) // Still spinning at high speed at 1000 yds

    // 3. Gyroscopic stability Sg > 1.3 throughout flight
    let sg500 = try #require(point500.stabilityFactorSg)
    #expect(sg500 > 1.3)

    // 4. Dynamic stability Sd > 0
    let sd500 = try #require(point500.dynamicStabilitySd)
    #expect(sd500 > 0)

    // 5. Natural spin drift emergence (deflection to the right for right twist)
    #expect(point1000.windage.converted(to: .inches).value > 0)
}
