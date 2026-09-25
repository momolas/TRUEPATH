//
//  InclineShooting.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utilities and approximation methods for inclined shooting (uphill and downhill fire).
public struct InclineShooting: Sendable, Equatable, Hashable {

    /**
     Calculates the equivalent flat-fire horizontal range using the classic **Rifleman's Rule**:

     `R_equivalent = R_line_of_sight * cos(incline_angle)`

     - Parameters:
       - lineOfSightRange: Direct slant distance to the target measured by laser rangefinder.
       - inclineAngle: Angle of inclination (positive uphill, negative downhill).

     - Returns:
       The equivalent horizontal range to look up drop table correction.
     */
    public static func riflemanEquivalentRange(
        lineOfSightRange: Measurement<UnitLength>,
        inclineAngle: Measurement<UnitAngle>
    ) -> Measurement<UnitLength> {
        let slantMeters = lineOfSightRange.converted(to: .meters).value
        let angleRad = inclineAngle.converted(to: .radians).value
        let cosine = abs(cos(angleRad))

        let horizMeters = slantMeters * cosine
        return Measurement(value: horizMeters, unit: .meters)
    }

    /**
     Calculates the equivalent range using the **Sierra Improved Cosine Rule**.

     At longer ranges and steeper angles, the simple Rifleman's rule slightly under-corrects because the projectile
     decelerates over the full slant distance. This improved method applies a correction factor (typically 0.20 to 0.35).

     `R_improved = R_los * (cos(theta) + factor * (1 - cos(theta)))`

     - Parameters:
       - lineOfSightRange: Slant distance to the target.
       - inclineAngle: Inclination angle.
       - factor: Empirical adjustment factor (default 0.25).

     - Returns:
       The refined equivalent range.
     */
    public static func sierraImprovedEquivalentRange(
        lineOfSightRange: Measurement<UnitLength>,
        inclineAngle: Measurement<UnitAngle>,
        factor: Double = 0.25
    ) -> Measurement<UnitLength> {
        let slantMeters = lineOfSightRange.converted(to: .meters).value
        let angleRad = inclineAngle.converted(to: .radians).value
        let cosine = abs(cos(angleRad))

        let effectiveCos = cosine + factor * (1.0 - cosine)
        let improvedMeters = slantMeters * effectiveCos
        return Measurement(value: improvedMeters, unit: .meters)
    }

    /**
     Calculates the Cosine Indicator factor from device pitch (e.g. from CoreMotion `motion.attitude.pitch`).

     - Parameter pitchRadians: Pitch angle in radians measured by device gyroscope/accelerometer.
     - Returns: The cosine factor (between 0.0 and 1.0).
     */
    public static func cosineFactor(fromPitchRadians pitchRadians: Double) -> Double {
        abs(cos(pitchRadians))
    }
}
