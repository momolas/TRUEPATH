//
//  TerminalBallistics.swift
//  BallisticsKit
//
//  Created by Antigravity on 09/10/2026.
//

import Foundation

/// Terminal ballistics indices and energy deposition models.
/// Based on Beat P. Kneubuehl (*Ballistics: Theory and Practice*), Philip P. Massaro (*Big Book of Ballistics*),
/// and Bryan Litz (*Applied Ballistics for Long Range Shooting*, Chapter 15: "Lethality of Long Range Hunting Bullets").
public struct TerminalBallistics: Sendable, Equatable, Hashable {

    /**
     Computes the **Matunas Optimal Game Weight (OGW)**.

     Formulated by Edward A. Matunas and adopted by Winchester and ballistic authorities,
     OGW estimates the maximum recommended animal weight (in pounds) for ethical harvest
     based on the projectile's remaining kinetic velocity and mass.

     $$OGW = \frac{V^3 \cdot W^2}{1.5 \times 10^{12}}$$

     - Parameters:
       - velocity: Terminal impact velocity.
       - bulletWeight: Bullet weight.
     - Returns: Optimal animal live weight as a `Measurement<UnitMass>`.
     */
    public static func optimalGameWeight(
        velocity: Measurement<UnitSpeed>,
        bulletWeight: Measurement<UnitMass>
    ) -> Measurement<UnitMass> {
        let vFPS = max(0.0, velocity.converted(to: .feetPerSecond).value)
        let wGrains = max(0.0, bulletWeight.converted(to: .grains).value)

        let ogwPounds = (pow(vFPS, 3) * pow(wGrains, 2)) / 1.5e12
        return Measurement(value: ogwPounds, unit: .pounds)
    }

    /**
     Computes the **Taylor Knockout Factor (TKOF)**.

     Developed by African professional hunter John "Pondoro" Taylor, the TKOF metric
     measures the delivered shock and momentum transmission of a projectile on heavy game.

     $$TKOF = \frac{W \cdot V \cdot d}{7000}$$

     - Parameters:
       - velocity: Terminal velocity.
       - bulletWeight: Projectile weight.
       - bulletDiameter: Projectile caliber / diameter.
     - Returns: The unitless Taylor Knockout score.
     */
    public static func taylorKnockoutFactor(
        velocity: Measurement<UnitSpeed>,
        bulletWeight: Measurement<UnitMass>,
        bulletDiameter: Measurement<UnitLength>
    ) -> Double {
        let vFPS = max(0.0, velocity.converted(to: .feetPerSecond).value)
        let wGrains = max(0.0, bulletWeight.converted(to: .grains).value)
        let dInches = max(0.0, bulletDiameter.converted(to: .inches).value)

        return (wGrains * vFPS * dInches) / 7000.0
    }

    /**
     Verifies whether the remaining velocity at impact exceeds the minimum reliable bullet expansion threshold.

     - Parameters:
       - impactVelocity: Remaining terminal velocity.
       - expansionThreshold: Minimum velocity required for jacket rupture / core expansion (default 1800 fps).
     - Returns: `true` if bullet will reliably mushroom/expand, `false` if it will act as a non-expanding solid.
     */
    public static func isAboveExpansionThreshold(
        impactVelocity: Measurement<UnitSpeed>,
        expansionThreshold: Measurement<UnitSpeed> = Measurement(value: 1800, unit: .feetPerSecond)
    ) -> Bool {
        impactVelocity.converted(to: .feetPerSecond).value >= expansionThreshold.converted(to: .feetPerSecond).value
    }
}

// MARK: - Point Convenience Extension

extension Point {

    /// Computes the Matunas Optimal Game Weight (OGW) at this trajectory point.
    public func optimalGameWeight(bulletWeight: Measurement<UnitMass>) -> Measurement<UnitMass> {
        TerminalBallistics.optimalGameWeight(velocity: velocity, bulletWeight: bulletWeight)
    }

    /// Computes the Taylor Knockout Factor (TKOF) at this trajectory point.
    public func taylorKnockoutFactor(
        bulletWeight: Measurement<UnitMass>,
        bulletDiameter: Measurement<UnitLength>
    ) -> Double {
        TerminalBallistics.taylorKnockoutFactor(
            velocity: velocity,
            bulletWeight: bulletWeight,
            bulletDiameter: bulletDiameter
        )
    }
}
