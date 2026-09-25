//
//  AcceleratedDragTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 20/09/2026.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func acceleratedDragTableInterpolation() {
    // Standard G7 table test points
    let points: [(mach: Double, cd: Double)] = [
        (0.00, 0.12),
        (0.50, 0.12),
        (0.80, 0.125),
        (1.00, 0.38),
        (1.20, 0.39),
        (1.50, 0.34),
        (2.00, 0.288),
        (3.00, 0.228),
        (4.00, 0.196),
        (5.00, 0.176)
    ]

    let table = AcceleratedDragTable(points: points, minMach: 0.0, maxMach: 5.0, step: 0.005)

    // Test specific Mach queries
    let queryMachs = [0.25, 0.80, 0.90, 1.00, 1.10, 1.50, 2.50, 4.50]
    let results = table.interpolate(machArray: queryMachs)

    #expect(results.count == queryMachs.count)

    // Mach 1.00 should match transonic peak ~0.38
    #expect(abs(results[3] - 0.38) < 0.005)

    // Mach 0.80 should be near 0.125
    #expect(abs(results[1] - 0.125) < 0.005)

    // Vector interpolation matches scalar interpolation
    for i in 0..<queryMachs.count {
        let scalarVal = table.interpolate(mach: queryMachs[i])
        #expect(abs(results[i] - scalarVal) < 1e-6)
    }
}

@Test func customDragModelAcceleratedEvaluation() {
    let cdm = CustomDragModel(dataPoints: [
        .init(mach: 0.5, cd: 0.15),
        .init(mach: 0.9, cd: 0.18),
        .init(mach: 1.0, cd: 0.42),
        .init(mach: 1.2, cd: 0.40),
        .init(mach: 2.0, cd: 0.30)
    ])

    let machQueries = [0.7, 0.95, 1.1, 1.5]
    let acceleratedResults = cdm.dragCoefficients(atMachArray: machQueries)

    #expect(acceleratedResults.count == machQueries.count)

    // Compare with direct CustomDragModel.dragCoefficient
    for i in 0..<machQueries.count {
        let directCd = cdm.dragCoefficient(atMach: machQueries[i])
        // Equidistant grid with 0.005 step should have < 0.5% difference from exact piecewise linear
        #expect(abs(acceleratedResults[i] - directCd) < 0.005)
    }
}
