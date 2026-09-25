//
//  Truing.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utilities for ballistic trajectory truing (calibrating true muzzle velocity V0 and ballistic coefficient BC from live-fire observations).
public struct Truing: Sendable, Equatable, Hashable {

    /// Specific errors encountered during trajectory truing.
    public enum TruingError: Error, Sendable, LocalizedError {
        case nonConvergent
        case invalidInputs(String)

        public var errorDescription: String? {
            switch self {
            case .nonConvergent:
                return "The truing solver failed to converge to a valid ballistic solution."
            case .invalidInputs(let msg):
                return "Invalid truing parameters: \(msg)"
            }
        }
    }

    /**
     Calibrates the true muzzle velocity ($V_0$ Truing) based on an observed elevation correction at a known distance.

     *Recommended protocol*: Perform live firing at a mid-range target in the supersonic regime (e.g. 300 to 600 meters / yards).
     Note the actual turret correction (or reticle holdover in MOA/MIL) that produced a bullseye impact.

     - Parameters:
       - observedDropCorrection: The actual elevation correction required to hit point of aim (e.g. 3.8 MIL or 13.1 MOA).
       - distance: The distance at which the live-fire test was conducted.
       - dragFunction: The aerodynamic drag function (.g1, .g7, etc.).
       - dragCoefficient: The projectile's catalog ballistic coefficient.
       - sightHeight: Height of sight above bore axis.
       - zeroRange: The firearm zero distance.
       - atmosphere: Environmental atmospheric conditions during test firing.
       - initialVelocityGuess: Initial estimate for muzzle velocity (default 2700 fps).
       - weight: Projectile weight.

     - Returns:
       The calibrated true muzzle velocity.
     */
    public static func calibrateMuzzleVelocity(
        observedDropCorrection: Measurement<UnitAngle>,
        atDistance distance: Measurement<UnitLength>,
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        atmosphere: Atmosphere? = nil,
        initialVelocityGuess: Measurement<UnitSpeed> = Measurement(value: 2700, unit: .feetPerSecond),
        weight: Measurement<UnitMass> = Measurement(value: 175, unit: .grains)
    ) -> Result<Measurement<UnitSpeed>, TruingError> {
        let distYards = distance.converted(to: .yards).value
        let zeroYards = zeroRange.converted(to: .yards).value
        let targetMOA = observedDropCorrection.converted(to: .minutesOfAngle).value

        guard distYards > zeroYards, dragCoefficient > 0 else {
            return .failure(.invalidInputs("Distance must be greater than zero range and drag coefficient must be positive."))
        }

        // Bisection search bounds for muzzle velocity (e.g. 400 fps to 5000 fps)
        var vLow = 400.0
        var vHigh = 5000.0

        for _ in 0..<20 {
            let vMid = (vLow + vHigh) / 2.0
            let solution = Ballistics.solve3DOF(
                preferredDistanceUnit: .yards,
                dragFunction: dragFunction,
                dragCoefficient: dragCoefficient,
                initialVelocity: Measurement(value: vMid, unit: .feetPerSecond),
                sightHeight: sightHeight,
                shootingAngle: Measurement(value: 0, unit: .degrees),
                zeroRange: zeroRange,
                atmosphere: atmosphere,
                windSpeed: Measurement(value: 0, unit: .milesPerHour),
                windAngle: 0,
                weight: weight,
                distanceStep: distance,
                maxRange: distance + Measurement(value: 25, unit: .yards)
            )

            guard let point = solution.getPoint(at: distance) else {
                return .failure(.nonConvergent)
            }

            let computedMOA = point.dropCorrection.converted(to: .minutesOfAngle).value

            // Higher velocity -> less drop -> smaller drop correction (MOA)
            if computedMOA > targetMOA {
                vLow = vMid
            } else {
                vHigh = vMid
            }
        }

        let calibratedFPS = (vLow + vHigh) / 2.0
        return .success(Measurement(value: calibratedFPS, unit: .feetPerSecond))
    }

    /**
     Calibrates the true Ballistic Coefficient ($BC$ Truing) based on an observed elevation correction at long range.

     *Recommended protocol*: Perform live firing at long range near the transonic transition zone (e.g. 800 to 1200 meters / yards)
     after muzzle velocity $V_0$ has already been trued at mid-range.

     - Parameters:
       - observedDropCorrection: The actual elevation correction required to hit center at long range.
       - distance: The long-range target distance.
       - muzzleVelocity: The calibrated / verified muzzle velocity.
       - dragFunction: The aerodynamic drag function (.g1, .g7, etc.).
       - sightHeight: Height of sight above bore axis.
       - zeroRange: The firearm zero distance.
       - atmosphere: Environmental atmospheric conditions during test firing.
       - dragCoefficientGuess: Initial estimate for ballistic coefficient.
       - weight: Projectile weight.

     - Returns:
       The calibrated true ballistic coefficient.
     */
    public static func calibrateBallisticCoefficient(
        observedDropCorrection: Measurement<UnitAngle>,
        atDistance distance: Measurement<UnitLength>,
        muzzleVelocity: Measurement<UnitSpeed>,
        dragFunction: DragFunction = .g1,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        atmosphere: Atmosphere? = nil,
        dragCoefficientGuess: Double = 0.400,
        weight: Measurement<UnitMass> = Measurement(value: 175, unit: .grains)
    ) -> Result<Double, TruingError> {
        let distYards = distance.converted(to: .yards).value
        let zeroYards = zeroRange.converted(to: .yards).value
        let targetMOA = observedDropCorrection.converted(to: .minutesOfAngle).value

        guard distYards > zeroYards, muzzleVelocity.value > 0 else {
            return .failure(.invalidInputs("Distance must be greater than zero range and muzzle velocity must be positive."))
        }

        // Bisection search bounds for BC (0.05 to 1.50)
        var bcLow = 0.05
        var bcHigh = 1.50

        for _ in 0..<20 {
            let bcMid = (bcLow + bcHigh) / 2.0
            let solution = Ballistics.solve3DOF(
                preferredDistanceUnit: .yards,
                dragFunction: dragFunction,
                dragCoefficient: bcMid,
                initialVelocity: muzzleVelocity,
                sightHeight: sightHeight,
                shootingAngle: Measurement(value: 0, unit: .degrees),
                zeroRange: zeroRange,
                atmosphere: atmosphere,
                windSpeed: Measurement(value: 0, unit: .milesPerHour),
                windAngle: 0,
                weight: weight,
                distanceStep: distance,
                maxRange: distance + Measurement(value: 25, unit: .yards)
            )

            guard let point = solution.getPoint(at: distance) else {
                return .failure(.nonConvergent)
            }

            let computedMOA = point.dropCorrection.converted(to: .minutesOfAngle).value

            // Higher BC -> less drag -> less drop -> smaller drop correction (MOA)
            if computedMOA > targetMOA {
                bcLow = bcMid
            } else {
                bcHigh = bcMid
            }
        }

        let calibratedBC = (bcLow + bcHigh) / 2.0
        return .success(calibratedBC)
    }
}
