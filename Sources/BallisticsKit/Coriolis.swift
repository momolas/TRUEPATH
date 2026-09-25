//
//  Coriolis.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utility for calculating trajectory deflections caused by the Coriolis effect (Earth's rotation).
public struct Coriolis: Sendable, Equatable, Hashable {

    /// Earth's angular rotation rate (rad/s).
    public static let earthAngularVelocity: Double = 7.292115e-5

    /**
     Calculates the horizontal and vertical deflection caused by Earth's rotation.

     - Parameters:
       - latitude: Firing position latitude (degrees, positive for North, negative for South).
       - azimuth: Shooting compass azimuth (degrees, 0° = North, 90° = East, 180° = South, 270° = West).
       - range: Downrange distance to the target.
       - timeOfFlight: Elapsed flight time.

     - Returns:
       A tuple containing:
       - `horizontal`: The lateral deflection (positive = right, negative = left).
       - `vertical`: The vertical deflection / Eötvös effect (positive = hit high, negative = hit low).
     */
    public static func deflection(
        latitude: Measurement<UnitAngle>,
        azimuth: Measurement<UnitAngle>,
        range: Measurement<UnitLength>,
        timeOfFlight: Measurement<UnitDuration>
    ) -> (horizontal: Measurement<UnitLength>, vertical: Measurement<UnitLength>) {
        let latRad = Math.degToRad(latitude.converted(to: .degrees).value)
        let azRad = Math.degToRad(azimuth.converted(to: .degrees).value)
        let xFeet = range.converted(to: .feet).value
        let tSec = timeOfFlight.converted(to: .seconds).value

        guard xFeet > 0, tSec > 0 else {
            return (Measurement(value: 0, unit: .inches), Measurement(value: 0, unit: .inches))
        }

        // Horizontal Coriolis deflection (drift right in Northern hemisphere, left in Southern)
        let horizFeet = earthAngularVelocity * sin(latRad) * xFeet * tSec
        let horizInches = horizFeet * 12.0

        // Vertical Coriolis / Eötvös deflection (shooting East hits high, shooting West hits low)
        let vertFeet = earthAngularVelocity * cos(latRad) * sin(azRad) * xFeet * tSec
        let vertInches = vertFeet * 12.0

        return (
            horizontal: Measurement(value: horizInches, unit: .inches),
            vertical: Measurement(value: vertInches, unit: .inches)
        )
    }
}
