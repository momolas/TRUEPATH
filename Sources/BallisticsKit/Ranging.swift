//
//  Ranging.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utilities for reticle ranging (Mil-Dot, MOA, MRAD subtensions) and optical distance estimation.
public struct Ranging: Sendable, Equatable, Hashable {

    /**
     Estimates the target distance based on known target physical size and measured angular subtension in the reticle.

     `Distance = Target Size / tan(Angle)`

     - Parameters:
       - targetSize: The physical dimension (height or width) of the target.
       - angularSize: The angle measured in the optic reticle (e.g. in Milliradians or MOA).

     - Returns:
       The calculated target distance in the requested unit.
     */
    public static func distance(
        targetSize: Measurement<UnitLength>,
        angularSize: Measurement<UnitAngle>
    ) -> Measurement<UnitLength> {
        let sizeMeters = targetSize.converted(to: .meters).value
        let angleRad = angularSize.converted(to: .radians).value

        guard sizeMeters > 0, angleRad > 0 else {
            return Measurement(value: 0, unit: .meters)
        }

        let distanceMeters = sizeMeters / tan(angleRad)
        return Measurement(value: distanceMeters, unit: .meters)
    }

    /**
     Calculates the angular subtension of a target of known size at a known distance.

     `Angle = atan(Target Size / Distance)`

     - Parameters:
       - targetSize: The physical dimension of the target.
       - distance: The distance to the target.

     - Returns:
       The angular subtension in the reticle.
     */
    public static func subtension(
        targetSize: Measurement<UnitLength>,
        distance: Measurement<UnitLength>
    ) -> Measurement<UnitAngle> {
        let sizeMeters = targetSize.converted(to: .meters).value
        let distMeters = distance.converted(to: .meters).value

        guard sizeMeters > 0, distMeters > 0 else {
            return Measurement(value: 0, unit: .milliradians)
        }

        let angleRad = atan(sizeMeters / distMeters)
        return Measurement(value: angleRad, unit: .radians)
    }

    /**
     Calculates the physical size of a target based on its distance and reticle subtension.

     `Target Size = Distance * tan(Angle)`

     - Parameters:
       - distance: The distance to the target.
       - angularSize: The measured angle in the reticle.

     - Returns:
       The calculated physical target size.
     */
    public static func targetSize(
        distance: Measurement<UnitLength>,
        angularSize: Measurement<UnitAngle>
    ) -> Measurement<UnitLength> {
        let distMeters = distance.converted(to: .meters).value
        let angleRad = angularSize.converted(to: .radians).value

        guard distMeters > 0, angleRad > 0 else {
            return Measurement(value: 0, unit: .meters)
        }

        let sizeMeters = distMeters * tan(angleRad)
        return Measurement(value: sizeMeters, unit: .meters)
    }
}
