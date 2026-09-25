//
//  InterpolationTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func testContinuousInterpolation() async throws {
    let solution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g1,
        dragCoefficient: 0.400,
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 10, unit: .milesPerHour),
        windAngle: 90,
        weight: Measurement(value: 168, unit: .grains),
        distanceStep: Measurement(value: 50, unit: .yards) // Large step of 50 yards
    )

    let point100 = try #require(solution.getPoint(at: Measurement(value: 100, unit: .yards)))
    let point150 = try #require(solution.getPoint(at: Measurement(value: 150, unit: .yards)))

    // Query intermediate fractional distance at 125 yards
    let point125 = try #require(solution.getPoint(at: Measurement(value: 125, unit: .yards)))

    // Intermediate metrics should lie strictly between the 100 yds and 150 yds values
    let drop100 = point100.drop.converted(to: .inches).value
    let drop125 = point125.drop.converted(to: .inches).value
    let drop150 = point150.drop.converted(to: .inches).value

    #expect(drop125 < drop100)
    #expect(drop125 > drop150)

    let v100 = point100.velocity.converted(to: .feetPerSecond).value
    let v125 = point125.velocity.converted(to: .feetPerSecond).value
    let v150 = point150.velocity.converted(to: .feetPerSecond).value

    #expect(v125 < v100)
    #expect(v125 > v150)

    // Midpoint should be approximately the mean
    let expectedDrop125 = (drop100 + drop150) / 2.0
    #expect(abs(drop125 - expectedDrop125) < 0.05)
}
