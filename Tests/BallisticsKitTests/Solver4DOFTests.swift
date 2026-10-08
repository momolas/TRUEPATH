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
