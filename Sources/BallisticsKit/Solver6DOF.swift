//
//  Solver6DOF.swift
//  BallisticsKit
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import simd

/// Backward-compatible 6-DOF alias, now unified under NATO STANAG 4355 Modified Point Mass.
@available(*, deprecated, renamed: "Solver4DOF")
public struct Solver6DOF: Sendable {

    @inlinable
    public static func solve(
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients? = nil,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double = 0.500,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        twist: Measurement<UnitLength>,
        twistDirection: TwistDirection = .right,
        atmosphere: Atmosphere? = nil,
        windSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        windAngle: Double = 0,
        latitude: Measurement<UnitAngle>? = nil,
        azimuth: Measurement<UnitAngle>? = nil,
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards),
        preferredDistanceUnit: UnitLength = .yards,
        tolerance: IntegratorTolerance = .standard,
        maxRange: Measurement<UnitLength>? = nil
    ) -> Ballistics {
        return Solver4DOF.solve(
            properties: properties,
            coefficients: coefficients,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            shootingAngle: shootingAngle,
            twist: twist,
            twistDirection: twistDirection,
            atmosphere: atmosphere,
            windSpeed: windSpeed,
            windAngle: windAngle,
            latitude: latitude,
            azimuth: azimuth,
            distanceStep: distanceStep,
            preferredDistanceUnit: preferredDistanceUnit,
            tolerance: tolerance,
            maxRange: maxRange
        )
    }
}
