//
//  RifleCant.swift
//  BallisticsKit
//
//  Created by Antigravity on 09/10/2026.
//

import Foundation

/// Models the ballistic trajectory deviations caused by rifle cant angle (lateral tilt of the firearm relative to gravity).
///
/// Based on Bryan Litz's *Applied Ballistics for Long Range Shooting* (Chapter 9: "Getting Control of Sights").
/// When a rifle is canted by angle $\phi$, the dialed elevation and windage corrections are rotated:
/// - Elevation loss: $\Delta \theta_{\text{elev}} = \theta_{\text{drop}}(\cos\phi - 1) + \theta_{\text{wind}}\sin\phi$
/// - Lateral deflection: $\Delta \theta_{\text{wind}} = -\theta_{\text{drop}}\sin\phi + \theta_{\text{wind}}(\cos\phi - 1)$
public struct RifleCant: Sendable, Equatable, Hashable {

    /**
     Calculates the angular error resulting from rifle cant.

     - Parameters:
       - dropCorrection: Total elevation correction required/dialed for the trajectory (upwards).
       - windageCorrection: Total windage correction required/dialed (positive right, negative left). Default is 0.
       - cantAngle: Rifle cant angle from true vertical. Positive indicates cant to the right (clockwise), negative to the left.

     - Returns:
       A tuple with the resulting elevation error (negative = impact lower) and windage error (positive = impact right, negative = impact left).
     */
    public static func angularError(
        dropCorrection: Measurement<UnitAngle>,
        windageCorrection: Measurement<UnitAngle> = Measurement(value: 0, unit: .minutesOfAngle),
        cantAngle: Measurement<UnitAngle>
    ) -> (elevationError: Measurement<UnitAngle>, windageError: Measurement<UnitAngle>) {
        let phi = cantAngle.converted(to: .radians).value
        let eVal = dropCorrection.converted(to: .minutesOfAngle).value
        let wVal = windageCorrection.converted(to: .minutesOfAngle).value

        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Effective rotated corrections
        let effectiveElev = eVal * cosPhi + wVal * sinPhi
        let effectiveWind = -eVal * sinPhi + wVal * cosPhi

        // Error is effective minus intended
        let dElev = effectiveElev - eVal
        let dWind = effectiveWind - wVal

        return (
            elevationError: Measurement(value: dElev, unit: .minutesOfAngle),
            windageError: Measurement(value: dWind, unit: .minutesOfAngle)
        )
    }

    /**
     Calculates the linear impact point shift on the target due to rifle cant.

     - Parameters:
       - targetDistance: Range to target.
       - dropCorrection: Elevation correction dialed.
       - windageCorrection: Windage correction dialed. Default is 0.
       - cantAngle: Cant angle (positive = cant right).

     - Returns:
       A tuple with vertical shift (negative = low impact) and horizontal shift (positive = right impact).
     */
    public static func linearImpactShift(
        targetDistance: Measurement<UnitLength>,
        dropCorrection: Measurement<UnitAngle>,
        windageCorrection: Measurement<UnitAngle> = Measurement(value: 0, unit: .minutesOfAngle),
        cantAngle: Measurement<UnitAngle>
    ) -> (verticalShift: Measurement<UnitLength>, horizontalShift: Measurement<UnitLength>) {
        let err = angularError(
            dropCorrection: dropCorrection,
            windageCorrection: windageCorrection,
            cantAngle: cantAngle
        )

        let distFeet = targetDistance.converted(to: .feet).value
        let elevRad = err.elevationError.converted(to: .radians).value
        let windRad = err.windageError.converted(to: .radians).value

        let vertInches = (distFeet * tan(elevRad)) * 12.0
        let horizInches = (distFeet * tan(windRad)) * 12.0

        return (
            verticalShift: Measurement(value: vertInches, unit: .inches),
            horizontalShift: Measurement(value: horizInches, unit: .inches)
        )
    }
}
