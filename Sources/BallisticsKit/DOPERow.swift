//
//  DOPERow.swift
//  BallisticsKit
//
//  Created by Antigravity on 08/10/2026.
//

import Foundation

/// Represents a structured row in a DOPE (Data On Previous Engagements) ballistic table,
/// exposing symmetric MRAD (0.1 MIL) and MOA (1/4 & 1/8 MOA) adjustments for both elevation and windage.
public struct DOPERow: Sendable, Equatable, Hashable {

    /// Target range.
    public let range: Measurement<UnitLength>

    /// Time of flight in seconds.
    public let travelTime: Measurement<UnitDuration>

    /// Residual projectile velocity.
    public let velocity: Measurement<UnitSpeed>

    /// Residual kinetic energy.
    public let energy: Measurement<UnitEnergy>

    // MARK: - Elevation Adjustments (Symmetric MRAD & MOA)

    /// Total vertical drop (in preferred distance unit).
    public let drop: Measurement<UnitLength>

    /// Elevation correction in Milliradians (MRAD / MIL).
    public let elevationMRAD: Double

    /// Elevation adjustment in standard 0.1 MRAD turret clicks.
    public let elevationClicksPointOneMRAD: Int

    /// Elevation correction in Minutes of Angle (MOA).
    public let elevationMOA: Double

    /// Elevation adjustment in 1/4 MOA turret clicks.
    public let elevationClicksQuarterMOA: Int

    /// Elevation adjustment in 1/8 MOA turret clicks.
    public let elevationClicksEighthMOA: Int

    // MARK: - Windage Adjustments (Symmetric MRAD & MOA)

    /// Total horizontal deflection combining wind, spin drift, and Coriolis.
    public let totalWindage: Measurement<UnitLength>

    /// Total windage correction in Milliradians (MRAD / MIL).
    public let windageMRAD: Double

    /// Total windage adjustment in standard 0.1 MRAD turret clicks.
    public let windageClicksPointOneMRAD: Int

    /// Total windage correction in Minutes of Angle (MOA).
    public let windageMOA: Double

    /// Total windage adjustment in 1/4 MOA turret clicks.
    public let windageClicksQuarterMOA: Int

    /// Total windage adjustment in 1/8 MOA turret clicks.
    public let windageClicksEighthMOA: Int

    // MARK: - Flight Regime

    /// Current Mach number.
    public let mach: Double

    /// Whether the projectile is supersonic (> Mach 1.2).
    public let isSupersonic: Bool

    /// Whether the projectile is in the transonic transition zone (Mach 0.8 - 1.2).
    public let isTransonic: Bool

    /// Whether the projectile is subsonic (< Mach 0.8).
    public let isSubsonic: Bool

    public init(
        range: Measurement<UnitLength>,
        travelTime: Measurement<UnitDuration>,
        velocity: Measurement<UnitSpeed>,
        energy: Measurement<UnitEnergy>,
        drop: Measurement<UnitLength>,
        elevationMRAD: Double,
        elevationClicksPointOneMRAD: Int,
        elevationMOA: Double,
        elevationClicksQuarterMOA: Int,
        elevationClicksEighthMOA: Int,
        totalWindage: Measurement<UnitLength>,
        windageMRAD: Double,
        windageClicksPointOneMRAD: Int,
        windageMOA: Double,
        windageClicksQuarterMOA: Int,
        windageClicksEighthMOA: Int,
        mach: Double,
        isSupersonic: Bool,
        isTransonic: Bool,
        isSubsonic: Bool
    ) {
        self.range = range
        self.travelTime = travelTime
        self.velocity = velocity
        self.energy = energy
        self.drop = drop
        self.elevationMRAD = elevationMRAD
        self.elevationClicksPointOneMRAD = elevationClicksPointOneMRAD
        self.elevationMOA = elevationMOA
        self.elevationClicksQuarterMOA = elevationClicksQuarterMOA
        self.elevationClicksEighthMOA = elevationClicksEighthMOA
        self.totalWindage = totalWindage
        self.windageMRAD = windageMRAD
        self.windageClicksPointOneMRAD = windageClicksPointOneMRAD
        self.windageMOA = windageMOA
        self.windageClicksQuarterMOA = windageClicksQuarterMOA
        self.windageClicksEighthMOA = windageClicksEighthMOA
        self.mach = mach
        self.isSupersonic = isSupersonic
        self.isTransonic = isTransonic
        self.isSubsonic = isSubsonic
    }
}
