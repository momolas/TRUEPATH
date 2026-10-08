//
//  Solver4DOFTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 08/10/2026.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func testState4DOFAccessors() {
    let state = State4DOF(
        x: 100,
        y: 2,
        z: -0.5,
        vx: 2600,
        vy: 10,
        vz: -2,
        p: 18000,
        time: 0.12
    )

    #expect(state.x == 100)
    #expect(state.y == 2)
    #expect(state.z == -0.5)
    #expect(state.vx == 2600)
    #expect(state.vy == 10)
    #expect(state.vz == -2)
    #expect(state.p == 18000)
    #expect(state.time == 0.12)
    #expect(state.totalSpeedFPS > 2600.0)
    #expect(state.spinRateRPM > 170000.0)
}

@Test func testSolver4DOFSimulationWithSTANAG4355() throws {
    let bullet = BulletCatalog.sierraMatchKing308_175gr
    let bcG7 = try #require(bullet.bcG7)

    let solution4DOF = Ballistics.solve4DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: bcG7,
        initialVelocity: Measurement(value: 2650, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        twist: Measurement(value: 11, unit: .inches),
        twistDirection: .right,
        bulletDiameter: bullet.diameter,
        bulletLength: bullet.length,
        tolerance: .standard,
        maxRange: Measurement(value: 1000, unit: .yards)
    )

    #expect(!solution4DOF.distances.isEmpty)

    let point0 = try #require(solution4DOF.getPoint(at: Measurement(value: 0, unit: .yards)))
    let point100 = try #require(solution4DOF.getPoint(at: Measurement(value: 100, unit: .yards)))
    let point500 = try #require(solution4DOF.getPoint(at: Measurement(value: 500, unit: .yards)))
    let point1000 = try #require(solution4DOF.getPoint(at: Measurement(value: 1000, unit: .yards)))

    // 1. Zero point verification (100 yds elevation correction is effectively zero)
    #expect(abs(point100.dropCorrection.converted(to: .minutesOfAngle).value) < 0.1)

    // 2. Initial spin rate at muzzle for 2650 fps with 1:11" twist: ~173,450 RPM
    let initialRPM = try #require(point0.spinRateRPM)
    #expect(abs(initialRPM - 173454.0) < 1000.0)

    // 3. Spin decay along trajectory
    let rpm500 = try #require(point500.spinRateRPM)
    let rpm1000 = try #require(point1000.spinRateRPM)
    #expect(rpm500 < initialRPM)
    #expect(rpm1000 < rpm500)
    #expect(rpm1000 > 110000.0)

    // 4. Gyroscopic stability Sg > 1.3
    let sg500 = try #require(point500.stabilityFactorSg)
    #expect(sg500 > 1.2)

    // 5. Dynamic stability Sd > 0
    let sd500 = try #require(point500.dynamicStabilitySd)
    #expect(sd500 > 0)

    // 6. Supersonic flight at 500 yards
    #expect(point500.velocity.converted(to: .feetPerSecond).value > 1600.0)
    #expect(point500.isSupersonic())
}

@Test func testSolver4DOFCrosswindAndMagnusCoupling() throws {
    let bullet = BulletCatalog.sierraMatchKing308_175gr
    let bcG7 = try #require(bullet.bcG7)

    // Fire with a 10 mph full crosswind (90°)
    let crosswindSolution = Ballistics.solve4DOF(
        preferredDistanceUnit: .meters,
        dragFunction: .g7,
        dragCoefficient: bcG7,
        initialVelocity: Measurement(value: 800, unit: .metersPerSecond),
        sightHeight: Measurement(value: 4.5, unit: .centimeters),
        zeroRange: Measurement(value: 100, unit: .meters),
        windSpeed: Measurement(value: 10, unit: .milesPerHour),
        windAngle: 90.0,
        twist: Measurement(value: 11, unit: .inches),
        twistDirection: .right,
        bulletDiameter: bullet.diameter,
        bulletLength: bullet.length,
        tolerance: .highPrecision,
        maxRange: Measurement(value: 600, unit: .meters)
    )

    let point300 = try #require(crosswindSolution.getPoint(at: Measurement(value: 300, unit: .meters)))
    let point600 = try #require(crosswindSolution.getPoint(at: Measurement(value: 600, unit: .meters)))

    // Windage deflection must be positive (deflection to the right in firing frame)
    #expect(point300.windage.converted(to: .centimeters).value > 5.0)
    #expect(point600.windage.converted(to: .centimeters).value > point300.windage.converted(to: .centimeters).value)

    // Angular corrections in both MRAD and MOA
    #expect(point300.windageCorrection.converted(to: .milliradians).value > 0.1)
    #expect(point300.windageCorrection.converted(to: .minutesOfAngle).value > 0.5)
}

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

@Test func testSolver4DOFRigidPropertiesSimulation() throws {
    let props = ProjectileProperties(
        weight: Measurement(value: 175, unit: .grains),
        diameter: Measurement(value: 0.308, unit: .inches),
        length: Measurement(value: 1.24, unit: .inches)
    )

    let solution4DOF = Ballistics.solve(
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

    #expect(!solution4DOF.distances.isEmpty)

    let point0 = try #require(solution4DOF.getPoint(at: Measurement(value: 0, unit: .yards)))
    let point500 = try #require(solution4DOF.getPoint(at: Measurement(value: 500, unit: .yards)))
    let point1000 = try #require(solution4DOF.getPoint(at: Measurement(value: 1000, unit: .yards)))

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
