//
//  SectionalDensity.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utility for calculating bullet sectional density (SD), form factor (i), and ballistic coefficient (BC).
public struct SectionalDensity: Sendable, Equatable, Hashable {

    /**
     Calculates the sectional density (SD) of a bullet.

     Sectional density is defined as the ratio of a bullet's mass to its cross-sectional area:
     `SD = weight (lb) / diameter (in)^2 = weight (gr) / (7000 * diameter (in)^2)`

     - Parameters:
       - weight: Bullet mass.
       - diameter: Bullet caliber / diameter.

     - Returns:
       The dimensionless sectional density (e.g. ~0.264 for a .308 175gr bullet).
     */
    public static func calculate(
        weight: Measurement<UnitMass>,
        diameter: Measurement<UnitLength>
    ) -> Double {
        let grains = weight.converted(to: .grains).value
        let inches = diameter.converted(to: .inches).value

        guard grains > 0, inches > 0 else { return 0 }

        return grains / (7000.0 * pow(inches, 2))
    }

    /**
     Calculates the aerodynamic form factor (i) of a bullet relative to a reference drag model.

     `i = SD / BC`

     - Parameters:
       - sectionalDensity: The bullet's sectional density.
       - ballisticCoefficient: The ballistic coefficient (BC) under the corresponding standard model.

     - Returns:
       The form factor (a value < 1.0 indicates less drag than the standard reference projectile).
     */
    public static func formFactor(
        sectionalDensity: Double,
        ballisticCoefficient: Double
    ) -> Double {
        guard ballisticCoefficient > 0 else { return 0 }
        return sectionalDensity / ballisticCoefficient
    }

    /**
     Calculates the ballistic coefficient (BC) from sectional density and form factor.

     `BC = SD / i`

     - Parameters:
       - sectionalDensity: The bullet's sectional density.
       - formFactor: The aerodynamic form factor (i).

     - Returns:
       The resulting ballistic coefficient.
     */
    public static func ballisticCoefficient(
        sectionalDensity: Double,
        formFactor: Double
    ) -> Double {
        guard formFactor > 0 else { return 0 }
        return sectionalDensity / formFactor
    }
}
