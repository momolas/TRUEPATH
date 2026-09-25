//
//  UnitSpeedTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 05/12/2024.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func speedUnits() async throws {
    #expect(Measurement<UnitSpeed>(value: 3300, unit: .feetPerSecond).converted(to: .metersPerSecond).value.isApproximatelyEqual(to: 1005.84, absoluteTolerance: 0.01))
    #expect(Measurement<UnitSpeed>(value: 900, unit: .metersPerSecond).converted(to: .feetPerSecond).value.isApproximatelyEqual(to: 2952.76, absoluteTolerance: 0.01))
}
