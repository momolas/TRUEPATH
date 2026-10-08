//
//  WindProfile.swift
//  BallisticsKit
//
//  Created by Antigravity on 01/10/2026.
//

import Foundation

/// Defines wind conditions along a trajectory, supporting constant wind, vertical boundary layer gradients, and range-segmented wind zones.
public enum WindProfile: Sendable, Equatable {

    /// Constant uniform wind along the entire trajectory.
    case constant(speed: Measurement<UnitSpeed>, angle: Double)

    /// Vertical atmospheric boundary layer wind gradient (Hellman Power Law).
    ///
    /// The wind speed increases with height above ground according to:
    /// $$V(z) = V_{\text{ref}} \cdot \left(\frac{\max(z, z_0)}{z_{\text{ref}}}\right)^\alpha$$
    /// - `referenceSpeed`: Wind speed measured at reference height (typically anemometer height, 2 meters / 6.5 ft).
    /// - `referenceHeight`: Anemometer measurement height above ground.
    /// - `roughnessExponent`: Hellman shear exponent $\alpha$ (0.10 for calm water/ice, 0.14 for open grass/prairie, 0.20 for scrubland/brush, 0.28 for wooded/urban).
    /// - `angle`: Wind direction in degrees (90° = direct crosswind from right, 270° = from left).
    case verticalGradient(
        referenceSpeed: Measurement<UnitSpeed>,
        referenceHeight: Measurement<UnitLength> = Measurement(value: 2, unit: .meters),
        roughnessExponent: Double = 0.143,
        angle: Double = 90
    )

    /// Range-segmented wind zones along the flight path (e.g. firing point vs mid-valley vs target zone).
    case segmented(zones: [WindZone])

    /// A specific downrange wind zone.
    public struct WindZone: Sendable, Equatable {
        /// The starting downrange distance of this wind zone (inclusive).
        public var startRange: Measurement<UnitLength>

        /// The ending downrange distance of this wind zone (exclusive, or open-ended if infinite).
        public var endRange: Measurement<UnitLength>

        /// Wind speed in this zone.
        public var speed: Measurement<UnitSpeed>

        /// Wind direction angle in degrees for this zone.
        public var angle: Double

        public init(
            startRange: Measurement<UnitLength>,
            endRange: Measurement<UnitLength>,
            speed: Measurement<UnitSpeed>,
            angle: Double
        ) {
            self.startRange = startRange
            self.endRange = endRange
            self.speed = speed
            self.angle = angle
        }
    }

    /**
     Evaluates the effective wind speed and angle at a specific point along the trajectory (downrange distance and height above ground).

     - Parameters:
       - range: Downrange horizontal distance from the muzzle.
       - heightAboveGround: Height of the projectile above the terrain surface.
     - Returns: A tuple containing the local wind speed and wind direction in degrees.
     */
    public func wind(
        atRange range: Measurement<UnitLength>,
        heightAboveGround: Measurement<UnitLength> = Measurement(value: 1.5, unit: .meters)
    ) -> (speed: Measurement<UnitSpeed>, angle: Double) {
        switch self {
        case .constant(let speed, let angle):
            return (speed, angle)

        case .verticalGradient(let refSpeed, let refHeight, let alpha, let angle):
            let zFeet = max(0.5, heightAboveGround.converted(to: .feet).value)
            let zRefFeet = max(0.5, refHeight.converted(to: .feet).value)
            let factor = pow(zFeet / zRefFeet, max(0.01, alpha))

            let baseSpeedFPS = refSpeed.converted(to: .feetPerSecond).value
            let localSpeedFPS = baseSpeedFPS * factor

            return (Measurement(value: localSpeedFPS, unit: .feetPerSecond).converted(to: refSpeed.unit), angle)

        case .segmented(let zones):
            guard !zones.isEmpty else {
                return (Measurement(value: 0, unit: .milesPerHour), 0)
            }

            let rangeMeters = range.converted(to: .meters).value

            for zone in zones {
                let startM = zone.startRange.converted(to: .meters).value
                let endM = zone.endRange.converted(to: .meters).value
                if rangeMeters >= startM && rangeMeters < endM {
                    return (zone.speed, zone.angle)
                }
            }

            // Default to last zone if past defined zones, or first if before
            if rangeMeters >= zones.last!.endRange.converted(to: .meters).value {
                return (zones.last!.speed, zones.last!.angle)
            }
            return (zones.first!.speed, zones.first!.angle)
        }
    }
}
