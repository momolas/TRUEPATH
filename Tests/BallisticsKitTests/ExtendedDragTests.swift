//
//  ExtendedDragTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func testExtendedDragModels() async throws {
    let models: [DragFunction] = [.g1, .g2, .g5, .g6, .g7, .g8]

    for model in models {
        let solution = Ballistics.solve3DOF(
            preferredDistanceUnit: .yards,
            dragFunction: model,
            dragCoefficient: 0.450,
            initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
            sightHeight: Measurement(value: 1.5, unit: .inches),
            shootingAngle: Measurement(value: 0, unit: .degrees),
            zeroRange: Measurement(value: 100, unit: .yards),
            windSpeed: Measurement(value: 10, unit: .milesPerHour),
            windAngle: 90,
            weight: Measurement(value: 175, unit: .grains),
            distanceStep: Measurement(value: 50, unit: .yards)
        )

        #expect(!solution.distances.isEmpty)
        let point100 = try #require(solution.getPoint(at: Measurement(value: 100, unit: .yards)))
        let point500 = try #require(solution.getPoint(at: Measurement(value: 500, unit: .yards)))

        // Trajectory sanity checks
        #expect(point100.velocity.converted(to: .feetPerSecond).value < 3000)
        #expect(point500.velocity.converted(to: .feetPerSecond).value < point100.velocity.converted(to: .feetPerSecond).value)
        #expect(point500.drop.converted(to: .inches).value < 0)
        #expect(point500.windage.converted(to: .inches).value > 0)
    }
}
