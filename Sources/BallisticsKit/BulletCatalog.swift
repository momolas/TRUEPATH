//
//  BulletCatalog.swift
//  BallisticsKit
//
//  Created by Antigravity on 01/10/2026.
//

import Foundation

/// Defines complete physical and aerodynamic specifications for a certified commercial match bullet.
public struct BulletProfile: Sendable, Equatable, Hashable, Codable {
    /// Commercial product designation (e.g. "Sierra MatchKing 175gr").
    public let name: String

    /// Bullet manufacturer (e.g. "Sierra", "Lapua", "Hornady", "Berger").
    public let manufacturer: String

    /// Nominal caliber family (e.g. ".308", "6.5mm", ".223 / 5.56", ".338").
    public let caliber: String

    /// Major diameter of the bullet shank.
    public let diameter: Measurement<UnitLength>

    /// Bullet total mass / weight.
    public let weight: Measurement<UnitMass>

    /// Total bullet length (tip to base).
    public let length: Measurement<UnitLength>

    /// Standard G7 ballistic coefficient (standard reference for boat-tail match projectiles).
    public let bcG7: Double?

    /// Standard G1 ballistic coefficient.
    public let bcG1: Double?

    public init(
        name: String,
        manufacturer: String,
        caliber: String,
        diameter: Measurement<UnitLength>,
        weight: Measurement<UnitMass>,
        length: Measurement<UnitLength>,
        bcG7: Double? = nil,
        bcG1: Double? = nil
    ) {
        self.name = name
        self.manufacturer = manufacturer
        self.caliber = caliber
        self.diameter = diameter
        self.weight = weight
        self.length = length
        self.bcG7 = bcG7
        self.bcG1 = bcG1
    }

    /// Converts this bullet profile into rigid-body `ProjectileProperties` for high-fidelity 6-DOF simulation.
    public func projectileProperties() -> ProjectileProperties {
        return ProjectileProperties(
            weight: weight,
            diameter: diameter,
            length: length
        )
    }
}

/// Standard reference library of factory-certified precision match and long-range projectiles.
public struct BulletCatalog: Sendable {

    // MARK: - .308 Caliber (7.62mm / 0.308")
    public static let sierraMatchKing308_175gr = BulletProfile(
        name: "Sierra MatchKing 175gr HPBT",
        manufacturer: "Sierra",
        caliber: ".308",
        diameter: Measurement(value: 0.308, unit: .inches),
        weight: Measurement(value: 175, unit: .grains),
        length: Measurement(value: 1.240, unit: .inches),
        bcG7: 0.243,
        bcG1: 0.505
    )

    public static let lapuaScenar308_185gr = BulletProfile(
        name: "Lapua Scenar 185gr OTM (GB432)",
        manufacturer: "Lapua",
        caliber: ".308",
        diameter: Measurement(value: 0.308, unit: .inches),
        weight: Measurement(value: 185, unit: .grains),
        length: Measurement(value: 1.340, unit: .inches),
        bcG7: 0.252,
        bcG1: 0.521
    )

    public static let bergerJuggernaut308_185gr = BulletProfile(
        name: "Berger Juggernaut Target 185gr OTM",
        manufacturer: "Berger",
        caliber: ".308",
        diameter: Measurement(value: 0.308, unit: .inches),
        weight: Measurement(value: 185, unit: .grains),
        length: Measurement(value: 1.348, unit: .inches),
        bcG7: 0.284,
        bcG1: 0.555
    )

    // MARK: - 6.5mm Caliber (0.264" - 6.5 Creedmoor / PRC)
    public static let hornadyELDMatch65_140gr = BulletProfile(
        name: "Hornady ELD-Match 140gr",
        manufacturer: "Hornady",
        caliber: "6.5mm",
        diameter: Measurement(value: 0.264, unit: .inches),
        weight: Measurement(value: 140, unit: .grains),
        length: Measurement(value: 1.380, unit: .inches),
        bcG7: 0.326,
        bcG1: 0.646
    )

    public static let bergerHybridTarget65_144gr = BulletProfile(
        name: "Berger Long Range Hybrid Target 144gr",
        manufacturer: "Berger",
        caliber: "6.5mm",
        diameter: Measurement(value: 0.264, unit: .inches),
        weight: Measurement(value: 144, unit: .grains),
        length: Measurement(value: 1.414, unit: .inches),
        bcG7: 0.336,
        bcG1: 0.655
    )

    public static let lapuaScenarL65_136gr = BulletProfile(
        name: "Lapua Scenar-L 136gr OTM (GB546)",
        manufacturer: "Lapua",
        caliber: "6.5mm",
        diameter: Measurement(value: 0.264, unit: .inches),
        weight: Measurement(value: 136, unit: .grains),
        length: Measurement(value: 1.378, unit: .inches),
        bcG7: 0.274,
        bcG1: 0.545
    )

    // MARK: - .223 / 5.56mm Caliber (0.224")
    public static let sierraMatchKing223_77gr = BulletProfile(
        name: "Sierra MatchKing 77gr HPBT",
        manufacturer: "Sierra",
        caliber: ".223",
        diameter: Measurement(value: 0.224, unit: .inches),
        weight: Measurement(value: 77, unit: .grains),
        length: Measurement(value: 0.990, unit: .inches),
        bcG7: 0.190,
        bcG1: 0.372
    )

    // MARK: - .338 Caliber (8.6mm / 0.338" - .338 Lapua Magnum)
    public static let lapuaScenar338_250gr = BulletProfile(
        name: "Lapua Scenar 250gr OTM (GB488)",
        manufacturer: "Lapua",
        caliber: ".338",
        diameter: Measurement(value: 0.338, unit: .inches),
        weight: Measurement(value: 250, unit: .grains),
        length: Measurement(value: 1.620, unit: .inches),
        bcG7: 0.336,
        bcG1: 0.675
    )

    public static let hornadyELDMatch338_285gr = BulletProfile(
        name: "Hornady ELD-Match 285gr",
        manufacturer: "Hornady",
        caliber: ".338",
        diameter: Measurement(value: 0.338, unit: .inches),
        weight: Measurement(value: 285, unit: .grains),
        length: Measurement(value: 1.830, unit: .inches),
        bcG7: 0.414,
        bcG1: 0.829
    )

    /// Complete registry of all built-in match bullets.
    public static let allBullets: [BulletProfile] = [
        sierraMatchKing308_175gr,
        lapuaScenar308_185gr,
        bergerJuggernaut308_185gr,
        hornadyELDMatch65_140gr,
        bergerHybridTarget65_144gr,
        lapuaScenarL65_136gr,
        sierraMatchKing223_77gr,
        lapuaScenar338_250gr,
        hornadyELDMatch338_285gr
    ]

    /// Filters bullets by caliber family (e.g. ".308", "6.5mm").
    public static func bullets(forCaliber caliber: String) -> [BulletProfile] {
        allBullets.filter { $0.caliber.localizedStandardContains(caliber) }
    }

    /// Finds a bullet by partial product name.
    public static func bullet(matching query: String) -> BulletProfile? {
        allBullets.first { $0.name.localizedStandardContains(query) }
    }
}
