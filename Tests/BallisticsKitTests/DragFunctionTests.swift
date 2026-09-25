//
//  DragFunctionTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func dragFunctionG1vsG7() async throws {
    // Solve with G1 drag function
    let solutionG1 = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g1,
        dragCoefficient: 0.414,
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 10, unit: .milesPerHour),
        windAngle: 90,
        weight: Measurement(value: 175, unit: .grains)
    )

    // Solve with G7 drag function (using corresponding G7 BC approx ~ 0.210)
    let solutionG7 = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: 0.210,
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 10, unit: .milesPerHour),
        windAngle: 90,
        weight: Measurement(value: 175, unit: .grains)
    )

    let point100G1 = try #require(solutionG1.getPoint(at: Measurement(value: 100, unit: .yards)))
    let point100G7 = try #require(solutionG7.getPoint(at: Measurement(value: 100, unit: .yards)))

    // Both should be zeroed around 100 yards (drop close to 0)
    #expect(abs(point100G1.drop.converted(to: .inches).value) < 0.1)
    #expect(abs(point100G7.drop.converted(to: .inches).value) < 0.1)

    // At 500 yards, both should compute consistent physical drops and wind drifts
    let point500G1 = try #require(solutionG1.getPoint(at: Measurement(value: 500, unit: .yards)))
    let point500G7 = try #require(solutionG7.getPoint(at: Measurement(value: 500, unit: .yards)))

    #expect(point500G1.drop.converted(to: .inches).value < -30)
    #expect(point500G7.drop.converted(to: .inches).value < -30)
    #expect(point500G1.velocity.converted(to: .feetPerSecond).value > 1500)
    #expect(point500G7.velocity.converted(to: .feetPerSecond).value > 1500)
}

@Test func dragFunctionCases() {
    #expect(DragFunction.allCases.count == 6)
    #expect(DragFunction.g1.rawValue == "G1")
    #expect(DragFunction.g2.rawValue == "G2")
    #expect(DragFunction.g5.rawValue == "G5")
    #expect(DragFunction.g6.rawValue == "G6")
    #expect(DragFunction.g7.rawValue == "G7")
    #expect(DragFunction.g8.rawValue == "G8")
}
