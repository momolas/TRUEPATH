//
//  Solver3DOFTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Testing
import Foundation
@testable import BallisticsKit

@Suite("Solver 3-DOF Tests")
struct Solver3DOFTests {

    @Test("Direct 3-DOF Simulation")
    func testDirectSolver3DOF() {
        let solution = Solver3DOF.solve(
            preferredDistanceUnit: .yards,
            dragFunction: .g7,
            dragCoefficient: 0.265,
            initialVelocity: Measurement(value: 2750, unit: .feetPerSecond),
            sightHeight: Measurement(value: 1.5, unit: .inches),
            shootingAngle: Measurement(value: 0, unit: .degrees),
            zeroRange: Measurement(value: 100, unit: .yards),
            windSpeed: Measurement(value: 10, unit: .milesPerHour),
            windAngle: 90
        )

        #expect(!solution.distances.isEmpty)
        let point100 = solution.getPoint(at: Measurement(value: 100, unit: .yards))
        #expect(point100 != nil)
        #expect(abs(point100!.drop.value) < 0.1) // Zeroed at 100 yards

        let point500 = solution.getPoint(at: Measurement(value: 500, unit: .yards))
        #expect(point500 != nil)
        #expect(point500!.drop.value < -40)
        #expect(point500!.windage.value > 5)
    }

    @Test("Solver3DOF vs Ballistics.solve3DOF Equivalence")
    func testEquivalenceWithFacade() {
        let solDirect = Solver3DOF.solve(
            preferredDistanceUnit: .meters,
            dragFunction: .g1,
            dragCoefficient: 0.450,
            initialVelocity: Measurement(value: 850, unit: .metersPerSecond),
            sightHeight: Measurement(value: 4.0, unit: .centimeters),
            zeroRange: Measurement(value: 200, unit: .meters)
        )

        let solFacade = Ballistics.solve3DOF(
            preferredDistanceUnit: .meters,
            dragFunction: .g1,
            dragCoefficient: 0.450,
            initialVelocity: Measurement(value: 850, unit: .metersPerSecond),
            sightHeight: Measurement(value: 4.0, unit: .centimeters),
            zeroRange: Measurement(value: 200, unit: .meters)
        )

        #expect(solDirect.distances.count == solFacade.distances.count)
        #expect(solDirect.getPoint(at: Measurement(value: 300, unit: .meters))?.drop.value == solFacade.getPoint(at: Measurement(value: 300, unit: .meters))?.drop.value)
    }
}
