//
//  UnitEnergyTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 12/12/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func energyUnits() async throws {
    #expect(Measurement<UnitEnergy>(value: 1, unit: .footPounds).converted(to: .joules).value.isApproximatelyEqual(to: 1.35582, absoluteTolerance: 0.000001))
    #expect(Measurement<UnitEnergy>(value: 1, unit: .joules).converted(to: .footPounds).value.isApproximatelyEqual(to: 0.737562, absoluteTolerance: 0.000001))
}
