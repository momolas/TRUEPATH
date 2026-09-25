//
//  SpinDrift.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utility for calculating gyroscopic spin drift (spin drift / Poisson effect) of a spinning projectile.
public struct SpinDrift: Sendable, Equatable, Hashable {

    /**
     Calculates the gyroscopic stability factor (Sg) of a bullet using the Miller rule.

     - Parameters:
       - weight: Projectile weight (e.g. in grains).
       - diameter: Projectile diameter / caliber (e.g. in inches).
       - length: Projectile length (e.g. in inches).
       - twist: Barrel rifling twist rate (e.g. 1 turn in 10 inches).
       - muzzleVelocity: Initial muzzle velocity.

     - Returns:
       The dimensionless gyroscopic stability factor Sg (typically between 1.3 and 2.0 for stable flight).
     */
    public static func stabilityFactor(
        weight: Measurement<UnitMass>,
        diameter: Measurement<UnitLength>,
        length: Measurement<UnitLength>,
        twist: Measurement<UnitLength>,
        muzzleVelocity: Measurement<UnitSpeed>? = nil
    ) -> Double {
        let m = weight.converted(to: .grains).value
        let d = diameter.converted(to: .inches).value
        let l = length.converted(to: .inches).value
        let t = twist.converted(to: .inches).value

        guard d > 0, l > 0, t > 0, m > 0 else { return 1.5 }

        let lInCalibers = l / d
        let tInCalibers = t / d

        // Miller stability rule formula
        var sg = (30.0 * m) / (pow(tInCalibers, 2) * pow(d, 3) * lInCalibers * (1.0 + pow(lInCalibers, 2)))

        // Velocity correction if muzzle velocity is provided (standard reference: 2800 fps)
        if let mv = muzzleVelocity {
            let vFPS = mv.converted(to: .feetPerSecond).value
            if vFPS > 0 {
                sg *= pow(vFPS / 2800.0, 1.0 / 6.0)
            }
        }

        return max(0.1, sg)
    }

    /**
     Calculates the lateral deflection caused by spin drift based on time of flight and gyroscopic stability factor.

     Uses the Litz empirical spin drift formula:
     `Drift (inches) = 1.25 * (Sg + 1.2) * (t ^ 1.83) * direction`

     - Parameters:
       - timeOfFlight: Flight duration of the projectile.
       - stabilityFactor: Gyroscopic stability factor (Sg, default is 1.5).
       - twistDirection: Barrel rifling direction (default is `.right`).

     - Returns:
       The lateral deflection as a `Measurement<UnitLength>` in inches.
     */
    public static func deflection(
        timeOfFlight: Measurement<UnitDuration>,
        stabilityFactor: Double = 1.5,
        twistDirection: TwistDirection = .right
    ) -> Measurement<UnitLength> {
        let t = timeOfFlight.converted(to: .seconds).value
        guard t > 0 else {
            return Measurement(value: 0, unit: .inches)
        }

        let driftInches = 1.25 * (stabilityFactor + 1.2) * pow(t, 1.83) * twistDirection.sign
        return Measurement(value: driftInches, unit: .inches)
    }
}
