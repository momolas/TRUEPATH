//
//  AerodynamicJump.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utilities for calculating Aerodynamic Jump (vertical trajectory deflection induced by crosswind acting on a spinning bullet).
public struct AerodynamicJump: Sendable, Equatable, Hashable {

    /**
     Calculates the vertical aerodynamic jump angle caused by crosswind acting on a gyroscopically stabilized bullet.

     For a right-hand twist barrel:
     - Left-to-right crosswind (+90°) produces a slight upward deflection (+).
     - Right-to-left crosswind (-90° / 270°) produces a slight downward deflection (-).

     - Parameters:
       - crosswindSpeed: The crosswind speed perpendicular to the line of fire.
       - initialVelocity: The muzzle velocity of the projectile.
       - twistDirection: Barrel rifling twist direction (.right or .left).
       - factor: Empirical jump factor (typically 0.015 MOA * fps / mph for modern sporting rifle bullets). Default is 0.015.

     - Returns:
       The angular vertical jump correction in minutes of angle.
     */
    public static func jumpAngle(
        crosswindSpeed: Measurement<UnitSpeed>,
        initialVelocity: Measurement<UnitSpeed>,
        twistDirection: TwistDirection = .right,
        factor: Double = 0.015
    ) -> Measurement<UnitAngle> {
        let windMPH = crosswindSpeed.converted(to: .milesPerHour).value
        let v0FPS = initialVelocity.converted(to: .feetPerSecond).value

        guard v0FPS > 0 else {
            return Measurement(value: 0, unit: .minutesOfAngle)
        }

        // Jump angle in MOA
        let moa = (windMPH / v0FPS) * factor * 100.0 * twistDirection.sign
        return Measurement(value: moa, unit: .minutesOfAngle)
    }
}
