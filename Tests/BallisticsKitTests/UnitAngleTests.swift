//
//  UnitAngleTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 05/12/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func angleUnits() async throws {
    #expect(Measurement<UnitAngle>(value: 1, unit: .milliradians).converted(to: .minutesOfAngle).value.isApproximatelyEqual(to: 3.43775, absoluteTolerance: 1e-5))
    #expect(Measurement<UnitAngle>(value: 1, unit: .milliradians).converted(to: .degrees).value.isApproximatelyEqual(to: 0.0572958, absoluteTolerance: 1e-5))
    #expect(Measurement<UnitAngle>(value: 1, unit: .minutesOfAngle).converted(to: .milliradians).value.isApproximatelyEqual(to: 0.290888, absoluteTolerance: 1e-5))
    #expect(Measurement<UnitAngle>(value: 1, unit: .minutesOfAngle).converted(to: .arcMinutes).value.isApproximatelyEqual(to: 1, absoluteTolerance: 1e-4))
}
