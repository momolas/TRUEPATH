//
//  SolutionTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 05/12/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func simpleSolution() async throws {

    // Generate a full ballistic solution
    let solution = Ballistics.solve3DOF(
        dragCoefficient: 0.414,
        initialVelocity: Measurement(value: 3300, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.8, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 0, unit: .milesPerHour),
        windAngle: 0,
        weight: Measurement(value: 120, unit: .grains)
    )

    let point0 = try #require(solution.getPoint(at: Measurement(value: 0, unit: .yards)))
    let point1 = try #require(solution.getPoint(at: Measurement(value: 100, unit: .yards)))
    let point2 = try #require(solution.getPoint(at: Measurement(value: 200, unit: .yards)))
    let point3 = try #require(solution.getPoint(at: Measurement(value: 300, unit: .yards)))
    let point4 = try #require(solution.getPoint(at: Measurement(value: 400, unit: .yards)))
    let point5 = try #require(solution.getPoint(at: Measurement(value: 500, unit: .yards)))

    #expect(point0.range.converted(to: .yards).value.isApproximatelyEqual(to: 0, absoluteTolerance: 1))
    #expect(point1.range.converted(to: .yards).value.isApproximatelyEqual(to: 100, absoluteTolerance: 1))
    #expect(point2.range.converted(to: .yards).value.isApproximatelyEqual(to: 200, absoluteTolerance: 1))
    #expect(point3.range.converted(to: .yards).value.isApproximatelyEqual(to: 300, absoluteTolerance: 1))
    #expect(point4.range.converted(to: .yards).value.isApproximatelyEqual(to: 400, absoluteTolerance: 1))
    #expect(point5.range.converted(to: .yards).value.isApproximatelyEqual(to: 500, absoluteTolerance: 1))

    #expect(point0.drop.converted(to: .inches).value.isApproximatelyEqual(to: -1.80, absoluteTolerance: 0.01))
    #expect(point1.drop.converted(to: .inches).value.isApproximatelyEqual(to: -0.00, absoluteTolerance: 0.01))
    #expect(point2.drop.converted(to: .inches).value.isApproximatelyEqual(to: -1.93, absoluteTolerance: 0.01))
    #expect(point3.drop.converted(to: .inches).value.isApproximatelyEqual(to: -8.23, absoluteTolerance: 0.01))
    #expect(point4.drop.converted(to: .inches).value.isApproximatelyEqual(to: -19.67, absoluteTolerance: 0.01))
    #expect(point5.drop.converted(to: .inches).value.isApproximatelyEqual(to: -37.19, absoluteTolerance: 0.01))

    #expect(point0.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point1.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point2.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point3.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point4.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point5.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))

    #expect(point0.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 3300, absoluteTolerance: 1))
    #expect(point1.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 3055, absoluteTolerance: 1))
    #expect(point2.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2824, absoluteTolerance: 1))
    #expect(point3.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2605, absoluteTolerance: 1))
    #expect(point4.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2395, absoluteTolerance: 1))
    #expect(point5.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2196, absoluteTolerance: 1))

    #expect(point0.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2902, absoluteTolerance: 1))
    #expect(point1.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2487, absoluteTolerance: 1))
    #expect(point2.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2125, absoluteTolerance: 1))
    #expect(point3.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 1808, absoluteTolerance: 1))
    #expect(point4.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 1529, absoluteTolerance: 1))
    #expect(point5.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 1285, absoluteTolerance: 1))

    #expect(point1.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0.00, absoluteTolerance: 0.01))
    #expect(point2.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0.92, absoluteTolerance: 0.01))
    #expect(point3.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 2.62, absoluteTolerance: 0.01))
    #expect(point4.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 4.70, absoluteTolerance: 0.01))
    #expect(point5.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 7.11, absoluteTolerance: 0.01))

    #expect(point1.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point2.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point3.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point4.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    #expect(point5.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
    
    #expect(point0.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 0.0, absoluteTolerance: 0.1))
    #expect(point1.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 94.5, absoluteTolerance: 0.1))
    #expect(point2.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 196.6, absoluteTolerance: 0.1))
    #expect(point3.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 307.2, absoluteTolerance: 0.1))
    #expect(point4.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 427.3, absoluteTolerance: 0.1))
    #expect(point5.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 558.1, absoluteTolerance: 0.1))
}

@Test func solutionWithAtmosphere() async throws {

    // Generate a full ballistic solution
    let solution = Ballistics.solve3DOF(
        dragCoefficient: 0.414,
        initialVelocity: Measurement(value: 3300, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.8, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        atmosphere: Atmosphere(
            altitude: Measurement(value: 10_000, unit: .feet),
            pressure: Measurement(value: 30.1, unit: .inchesOfMercury),
            temperature: Measurement(value: 5, unit: .fahrenheit),
            relativeHumidity: 0.9
        ),
        windSpeed: Measurement(value: 20, unit: .milesPerHour),
        windAngle: 135,
        weight: Measurement(value: 120, unit: .grains)
    )

    let point0 = try #require(solution.getPoint(at: Measurement(value: 0, unit: .yards)))
    let point1 = try #require(solution.getPoint(at: Measurement(value: 100, unit: .yards)))
    let point2 = try #require(solution.getPoint(at: Measurement(value: 200, unit: .yards)))
    let point3 = try #require(solution.getPoint(at: Measurement(value: 300, unit: .yards)))
    let point4 = try #require(solution.getPoint(at: Measurement(value: 400, unit: .yards)))
    let point5 = try #require(solution.getPoint(at: Measurement(value: 500, unit: .yards)))

    #expect(point0.range.converted(to: .yards).value.isApproximatelyEqual(to: 0, absoluteTolerance: 1))
    #expect(point1.range.converted(to: .yards).value.isApproximatelyEqual(to: 100, absoluteTolerance: 1))
    #expect(point2.range.converted(to: .yards).value.isApproximatelyEqual(to: 200, absoluteTolerance: 1))
    #expect(point3.range.converted(to: .yards).value.isApproximatelyEqual(to: 300, absoluteTolerance: 1))
    #expect(point4.range.converted(to: .yards).value.isApproximatelyEqual(to: 400, absoluteTolerance: 1))
    #expect(point5.range.converted(to: .yards).value.isApproximatelyEqual(to: 500, absoluteTolerance: 1))

    #expect(point0.drop.converted(to: .inches).value.isApproximatelyEqual(to: -1.80, absoluteTolerance: 0.01))
    #expect(point1.drop.converted(to: .inches).value.isApproximatelyEqual(to: -0.00, absoluteTolerance: 0.01))
    #expect(point2.drop.converted(to: .inches).value.isApproximatelyEqual(to: -1.81, absoluteTolerance: 0.01))
    #expect(point3.drop.converted(to: .inches).value.isApproximatelyEqual(to: -7.66, absoluteTolerance: 0.01))
    #expect(point4.drop.converted(to: .inches).value.isApproximatelyEqual(to: -18.10, absoluteTolerance: 0.01))
    #expect(point5.drop.converted(to: .inches).value.isApproximatelyEqual(to: -33.74, absoluteTolerance: 0.01))

    #expect(point0.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0.0, absoluteTolerance: 0.01))
    #expect(point1.windage.converted(to: .inches).value.isApproximatelyEqual(to: 0.67, absoluteTolerance: 0.01))
    #expect(point2.windage.converted(to: .inches).value.isApproximatelyEqual(to: 2.78, absoluteTolerance: 0.01))
    #expect(point3.windage.converted(to: .inches).value.isApproximatelyEqual(to: 6.43, absoluteTolerance: 0.01))
    #expect(point4.windage.converted(to: .inches).value.isApproximatelyEqual(to: 11.76, absoluteTolerance: 0.01))
    #expect(point5.windage.converted(to: .inches).value.isApproximatelyEqual(to: 18.91, absoluteTolerance: 0.01))

    #expect(point0.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 3300, absoluteTolerance: 1))
    #expect(point1.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 3110, absoluteTolerance: 1))
    #expect(point2.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2930, absoluteTolerance: 1))
    #expect(point3.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2756, absoluteTolerance: 1))
    #expect(point4.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2589, absoluteTolerance: 1))
    #expect(point5.velocity.converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2428, absoluteTolerance: 1))

    #expect(point0.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2902, absoluteTolerance: 1))
    #expect(point1.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2578, absoluteTolerance: 1))
    #expect(point2.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2287, absoluteTolerance: 1))
    #expect(point3.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 2024, absoluteTolerance: 1))
    #expect(point4.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 1787, absoluteTolerance: 1))
    #expect(point5.energy.converted(to: .footPounds).value.isApproximatelyEqual(to: 1571, absoluteTolerance: 1))

    #expect(point1.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0.00, absoluteTolerance: 0.01))
    #expect(point2.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0.87, absoluteTolerance: 0.01))
    #expect(point3.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 2.45, absoluteTolerance: 0.01))
    #expect(point4.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 4.33, absoluteTolerance: 0.01))
    #expect(point5.dropCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 6.45, absoluteTolerance: 0.01))

    #expect(point1.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 0.65, absoluteTolerance: 0.01))
    #expect(point2.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 1.33, absoluteTolerance: 0.01))
    #expect(point3.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 2.05, absoluteTolerance: 0.01))
    #expect(point4.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 2.81, absoluteTolerance: 0.01))
    #expect(point5.windageCorrection.converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 3.62, absoluteTolerance: 0.01))
    
    #expect(point0.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 0.0, absoluteTolerance: 0.1))
    #expect(point1.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 93.6, absoluteTolerance: 0.1))
    #expect(point2.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 193.0, absoluteTolerance: 0.1))
    #expect(point3.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 298.6, absoluteTolerance: 0.1))
    #expect(point4.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 410.9, absoluteTolerance: 0.1))
    #expect(point5.travelTime.converted(to: .milliseconds).value.isApproximatelyEqual(to: 530.5, absoluteTolerance: 0.1))
}

@Test func solutionWithSmallStep() async throws {
    // Generate a solution with small step to verify sampling robustness
    let solution = Ballistics.solve3DOF(
        dragCoefficient: 0.414,
        initialVelocity: Measurement(value: 3000, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        shootingAngle: Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement(value: 100, unit: .yards),
        windSpeed: Measurement(value: 0, unit: .milesPerHour),
        windAngle: 0,
        weight: Measurement(value: 150, unit: .grains),
        distanceStep: Measurement(value: 0.1, unit: .yards) // Small step: 0.3 feet
    )

    // Check existence of point at 0.2 yards.
    // The integration step is roughly 0.5 feet, which is larger than 0.3 feet (0.1 yards).
    // This ensures that the loop correctly catches multiple points within a single integration step.
    let point02 = try #require(solution.getPoint(at: Measurement(value: 0.2, unit: .yards)))
    #expect(point02.range.converted(to: .yards).value.isApproximatelyEqual(to: 0.2, absoluteTolerance: 0.001))

    let point05 = try #require(solution.getPoint(at: Measurement(value: 0.5, unit: .yards)))
    #expect(point05.range.converted(to: .yards).value.isApproximatelyEqual(to: 0.5, absoluteTolerance: 0.001))
}
