//
//  UnitMassTests.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 12/12/2024.
//

import Foundation
import Testing
import BallisticsKit

@Test func massUnits() async throws {
    #expect(Measurement<UnitMass>(value: 1, unit: .grains).converted(to: .kilograms).value.isApproximatelyEqual(to: 6.47989e-5, absoluteTolerance: 1e-10))
    #expect(Measurement<UnitMass>(value: 1, unit: .kilograms).converted(to: .grains).value.isApproximatelyEqual(to: 15432.4, absoluteTolerance: 0.1))
}
