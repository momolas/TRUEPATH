//
//  PBRTests.swift
//  swift-ballistics
//
//  Created by Jules on 26/02/2025.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func calculatePBR() async throws {
    let result = PBR.solve(
        dragCoefficient: 0.414,
        initialVelocity: 3000,
        sightHeight: 1.5,
        vitalSize: 8 // 8 inch target
    )

    switch result {
    case .success(let pbr):
        #expect(pbr.nearZeroYards > 0)
        #expect(pbr.farZeroYards > pbr.nearZeroYards)
        #expect(pbr.maxPBRYards > pbr.farZeroYards)
        #expect(pbr.minPBRYards >= 0)

        // Sanity checks for a 3000 fps projectile
        // Near zero is typically around 25-50 yards
        // Far zero around 250-300 yards
        // Max PBR around 290-340 yards
        #expect(pbr.nearZeroYards < 100)
        #expect(pbr.farZeroYards > 100)
        #expect(pbr.maxPBRYards > 200)

    case .failure(let error):
        Issue.record("PBR calculation failed with error: \(error)")
    }
}

@Test func calculatePBRWithMeasurements() async throws {
    let result = PBR.solve(
        dragFunction: .g7,
        dragCoefficient: 0.25,
        initialVelocity: Measurement(value: 850, unit: .metersPerSecond),
        sightHeight: Measurement(value: 4.0, unit: .centimeters),
        vitalSize: Measurement(value: 20, unit: .centimeters)
    )

    switch result {
    case .success(let pbr):
        #expect(pbr.nearZeroYards > 0)
        #expect(pbr.farZeroYards > pbr.nearZeroYards)
        #expect(pbr.maxPBRYards > pbr.farZeroYards)

        // Typed Measurement accessors
        #expect(pbr.nearZero.value == Double(pbr.nearZeroYards))
        #expect(pbr.farZero.value == Double(pbr.farZeroYards))
        #expect(pbr.minPBR.value == Double(pbr.minPBRYards))
        #expect(pbr.maxPBR.value == Double(pbr.maxPBRYards))
        #expect(pbr.sightInElevationOffset.unit == .inches)

        // Codable test
        let encoded = try JSONEncoder().encode(pbr)
        let decoded = try JSONDecoder().decode(PBR.self, from: encoded)
        #expect(decoded == pbr)

    case .failure(let error):
        Issue.record("PBR Measurement calculation failed: \(error)")
    }
}
