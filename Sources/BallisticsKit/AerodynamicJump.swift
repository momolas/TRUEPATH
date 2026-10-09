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

    /**
     Calculates the exact physical aerodynamic jump angle using Robert L. McCoy's formulation (BRL / STANAG 4355).

     Formula (McCoy, *Modern Exterior Ballistics*, Chapter 12):
     $$\delta_{\text{jump}} = \frac{C_{L\alpha}}{C_{M\alpha}} \cdot \frac{I_x}{m \cdot d} \cdot \frac{p \cdot W_{\text{cross}}}{V_0^2}$$

     - Parameters:
       - crosswindSpeed: The crosswind speed (positive from left-to-right, negative right-to-left).
       - initialVelocity: The muzzle velocity $V_0$.
       - properties: Projectile mass, caliber, and moments of inertia.
       - coefficients: Aerodynamic coefficient functions ($C_{L\alpha}$ and $C_{M\alpha}$).
       - mach: Mach number for evaluating derivatives (typically at muzzle launch, Mach 1.5 to 3.0).
       - twist: Barrel rifling twist rate (e.g. 1 turn in 10 inches).
       - twistDirection: Barrel twist direction (.right or .left).

     - Returns:
       The exact vertical aerodynamic jump angle.
     */
    public static func physicalJumpAngle(
        crosswindSpeed: Measurement<UnitSpeed>,
        initialVelocity: Measurement<UnitSpeed>,
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients,
        mach: Double = 2.4,
        twist: Measurement<UnitLength>,
        twistDirection: TwistDirection = .right
    ) -> Measurement<UnitAngle> {
        let v0FPS = max(10.0, initialVelocity.converted(to: .feetPerSecond).value)
        let wCrossFPS = crosswindSpeed.converted(to: .feetPerSecond).value
        let twistInches = twist.converted(to: .inches).value
        let twistFeet = max(0.01, twistInches / 12.0)

        // Spin rate p0 = (2 * pi * V0 / twistFeet) * sign
        let p0 = (2.0 * Double.pi * v0FPS / twistFeet) * twistDirection.sign

        let clA = coefficients.clAlpha(mach)
        let cmA = max(1e-6, coefficients.cmAlpha(mach))
        let ix = properties.axialInertia
        let mass = properties.massSlugs
        let diamFeet = properties.diameter.converted(to: .inches).value / 12.0

        // McCoy jump in radians
        let ratioAero = clA / cmA
        let ratioInertia = ix / max(1e-9, mass * diamFeet)
        let kinematics = (p0 * wCrossFPS) / (v0FPS * v0FPS)

        let jumpRad = ratioAero * ratioInertia * kinematics
        let jumpMOA = Math.radToMOA(jumpRad)

        return Measurement(value: jumpMOA, unit: .minutesOfAngle)
    }
}

