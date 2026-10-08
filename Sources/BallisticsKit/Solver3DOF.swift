//
//  Solver3DOF.swift
//  BallisticsKit
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Backward-compatible 3-DOF alias, now unified under NATO STANAG 4355 Modified Point Mass.
@available(*, deprecated, renamed: "Solver4DOF")
public struct Solver3DOF: Sendable {

    @inlinable
    public static func solve(
        preferredDistanceUnit: UnitLength = .yards,
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement<UnitLength>,
        atmosphere: Atmosphere? = nil,
        windSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        windAngle: Double = 0,
        weight: Measurement<UnitMass> = Measurement<UnitMass>(value: 0, unit: .grains),
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards),
        twist: Measurement<UnitLength>? = nil,
        twistDirection: TwistDirection = .right,
        bulletDiameter: Measurement<UnitLength>? = nil,
        bulletLength: Measurement<UnitLength>? = nil,
        latitude: Measurement<UnitAngle>? = nil,
        azimuth: Measurement<UnitAngle>? = nil,
        maxRange: Measurement<UnitLength>? = nil
    ) -> Ballistics {
        return Solver4DOF.solve(
            preferredDistanceUnit: preferredDistanceUnit,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            shootingAngle: shootingAngle,
            zeroRange: zeroRange,
            atmosphere: atmosphere,
            windSpeed: windSpeed,
            windAngle: windAngle,
            weight: weight,
            distanceStep: distanceStep,
            twist: twist,
            twistDirection: twistDirection,
            bulletDiameter: bulletDiameter,
            bulletLength: bulletLength,
            latitude: latitude,
            azimuth: azimuth,
            maxRange: maxRange
        )
    }
}
