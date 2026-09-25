//
//  Point.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents a specific point along the trajectory of a projectile.
///
/// This struct captures various ballistic data at a given range, including position, velocity, energy, timing,
/// advanced long-range effects (spin drift, Coriolis deflections), 6-DOF dynamic metrics, and optical turret click helpers.
public struct Point: Sendable, Equatable, Hashable {

    /// The distance from the muzzle to this point.
    public let range: Measurement<UnitLength>

    /// The vertical drop of the projectile at this point relative to the line of sight (due to gravity & zero angle).
    public let drop: Measurement<UnitLength>

    /// The angular correction required to compensate for the aerodynamic drop.
    public let dropCorrection: Measurement<UnitAngle>

    /// The horizontal drift of the projectile due to crosswind alone.
    public let windage: Measurement<UnitLength>

    /// The angular correction required to compensate for crosswind drift alone.
    public let windageCorrection: Measurement<UnitAngle>

    /// The travel time as a Measurement unit.
    public let travelTime: Measurement<UnitDuration>

    /// The total velocity of the projectile at this point.
    public let velocity: Measurement<UnitSpeed>

    /// The horizontal component of the velocity.
    public let velocityX: Measurement<UnitSpeed>

    /// The vertical component of the velocity.
    public let velocityY: Measurement<UnitSpeed>

    /// The kinetic energy of the projectile at this point.
    public let energy: Measurement<UnitEnergy>

    /// Gyroscopic spin drift deflection at this point (if rifle twist parameters were provided).
    public let spinDrift: Measurement<UnitLength>?

    /// Horizontal Coriolis deflection due to Earth's rotation (if latitude & azimuth were provided).
    public let coriolisHorizontal: Measurement<UnitLength>?

    /// Vertical Coriolis deflection / Eötvös effect (if latitude & azimuth were provided).
    public let coriolisVertical: Measurement<UnitLength>?

    // MARK: - 6-DOF Rigid-Body Dynamics Metrics

    /// Bullet axial spin rate at this point in revolutions per minute (RPM) (6-DOF mode).
    public let spinRateRPM: Double?

    /// Local gyroscopic stability factor Sg(t) at this point (6-DOF mode).
    public let stabilityFactorSg: Double?

    /// Local dynamic stability factor Sd(t) at this point (6-DOF mode).
    public let dynamicStabilitySd: Double?

    /// Exact equilibrium angle of attack / yaw of repose (6-DOF mode).
    public let yawOfReposeAngle: Measurement<UnitAngle>?

    /// The time elapsed since the projectile was fired, in seconds (convenience property computed from travelTime).
    public var seconds: Double {
        travelTime.converted(to: .seconds).value
    }

    /// Total horizontal deflection combining crosswind, gyroscopic spin drift, and horizontal Coriolis effect.
    public var totalWindage: Measurement<UnitLength> {
        let baseInches = windage.converted(to: .inches).value
        let spinInches = spinDrift?.converted(to: .inches).value ?? 0
        let corInches = coriolisHorizontal?.converted(to: .inches).value ?? 0
        return Measurement(value: baseInches + spinInches + corInches, unit: .inches)
    }

    /// Total angular windage correction for the total horizontal deflection.
    public var totalWindageCorrection: Measurement<UnitAngle> {
        let xFeet = max(1e-9, range.converted(to: .feet).value)
        let totalFeet = totalWindage.converted(to: .feet).value
        let moa = Math.radToMOA(atan(totalFeet / xFeet))
        return Measurement(value: moa, unit: .minutesOfAngle)
    }

    /// Total vertical drop combining gravity trajectory and vertical Coriolis (Eötvös) effect.
    public var totalDrop: Measurement<UnitLength> {
        let baseInches = drop.converted(to: .inches).value
        let corVertInches = coriolisVertical?.converted(to: .inches).value ?? 0
        return Measurement(value: baseInches + corVertInches, unit: .inches)
    }

    /// Total angular drop correction for the total vertical drop.
    public var totalDropCorrection: Measurement<UnitAngle> {
        let xFeet = max(1e-9, range.converted(to: .feet).value)
        let totalFeet = totalDrop.converted(to: .feet).value
        let moa = -Math.radToMOA(atan(totalFeet / xFeet))
        return Measurement(value: moa, unit: .minutesOfAngle)
    }

    // MARK: - Optic Turret Clicks Helpers

    /// Computes the number of turret elevation clicks needed to compensate for drop.
    public func elevationClicks(_ click: TurretClick = .oneFourthMOA) -> Int {
        click.clicks(for: dropCorrection)
    }

    /// Computes the number of turret windage clicks needed to compensate for crosswind drift.
    public func windageClicks(_ click: TurretClick = .oneFourthMOA) -> Int {
        click.clicks(for: windageCorrection)
    }

    /// Computes the number of turret elevation clicks needed for total vertical drop (including Coriolis).
    public func totalElevationClicks(_ click: TurretClick = .oneFourthMOA) -> Int {
        click.clicks(for: totalDropCorrection)
    }

    /// Computes the number of turret windage clicks needed for total windage (including spin drift and Coriolis).
    public func totalWindageClicks(_ click: TurretClick = .oneFourthMOA) -> Int {
        click.clicks(for: totalWindageCorrection)
    }

    // MARK: - Flight Regime Helpers

    /// Computes the Mach number at this point for a given speed of sound.
    public func machNumber(
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> Double {
        let soundFPS = speedOfSound.converted(to: .feetPerSecond).value
        let vFPS = velocity.converted(to: .feetPerSecond).value
        guard soundFPS > 0 else { return 0 }
        return vFPS / soundFPS
    }

    /// Returns `true` if the projectile is in supersonic flight (> Mach 1.2).
    public func isSupersonic(
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> Bool {
        machNumber(speedOfSound: speedOfSound) > 1.2
    }

    /// Returns `true` if the projectile is in the transonic transition zone (Mach 0.8 to 1.2).
    public func isTransonic(
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> Bool {
        let m = machNumber(speedOfSound: speedOfSound)
        return m >= 0.8 && m <= 1.2
    }

    /// Returns `true` if the projectile is in subsonic flight (< Mach 0.8).
    public func isSubsonic(
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> Bool {
        machNumber(speedOfSound: speedOfSound) < 0.8
    }

    public init(
        range: Measurement<UnitLength>,
        drop: Measurement<UnitLength>,
        dropCorrection: Measurement<UnitAngle>,
        windage: Measurement<UnitLength>,
        windageCorrection: Measurement<UnitAngle>,
        travelTime: Measurement<UnitDuration>,
        velocity: Measurement<UnitSpeed>,
        velocityX: Measurement<UnitSpeed>,
        velocityY: Measurement<UnitSpeed>,
        energy: Measurement<UnitEnergy>,
        spinDrift: Measurement<UnitLength>? = nil,
        coriolisHorizontal: Measurement<UnitLength>? = nil,
        coriolisVertical: Measurement<UnitLength>? = nil,
        spinRateRPM: Double? = nil,
        stabilityFactorSg: Double? = nil,
        dynamicStabilitySd: Double? = nil,
        yawOfReposeAngle: Measurement<UnitAngle>? = nil
    ) {
        self.range = range
        self.drop = drop
        self.dropCorrection = dropCorrection
        self.windage = windage
        self.windageCorrection = windageCorrection
        self.travelTime = travelTime
        self.velocity = velocity
        self.velocityX = velocityX
        self.velocityY = velocityY
        self.energy = energy
        self.spinDrift = spinDrift
        self.coriolisHorizontal = coriolisHorizontal
        self.coriolisVertical = coriolisVertical
        self.spinRateRPM = spinRateRPM
        self.stabilityFactorSg = stabilityFactorSg
        self.dynamicStabilitySd = dynamicStabilitySd
        self.yawOfReposeAngle = yawOfReposeAngle
    }
}
