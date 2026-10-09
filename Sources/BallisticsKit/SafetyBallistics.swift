//
//  SafetyBallistics.swift
//  BallisticsKit
//
//  Created by Antigravity on 09/10/2026.
//

import Foundation

/// Range safety, maximum range calculation, and ricochet boundary modeling.
/// Based on Beat P. Kneubuehl (*Ballistics: Theory and Practice*, Chapters 7: "Ricochets" and 8: "Safety on Shooting Ranges")
/// and Robert L. McCoy (*Modern Exterior Ballistics*).
public struct SafetyBallistics: Sendable {

    /// Result of an absolute maximum range calculation.
    public struct MaximumRangeResult: Sendable, Equatable {
        /// The absolute maximum downrange distance the projectile can achieve at ground level.
        public let maximumRange: Measurement<UnitLength>

        /// The optimal launch elevation angle that produces maximum range (typically 30° to 36° under aerodynamic drag).
        public let optimalLaunchAngle: Measurement<UnitAngle>

        /// The maximum apogee / vertex altitude above the firing line reached by the projectile.
        public let vertexAltitude: Measurement<UnitLength>

        /// Total flight time until ground impact.
        public let totalFlightTime: Measurement<UnitDuration>

        /// Remaining terminal velocity at ground impact.
        public let terminalVelocity: Measurement<UnitSpeed>
    }

    /// Surface types for ricochet critical angle and velocity retention estimation.
    public enum RicochetSurface: Sendable, Equatable {
        case water
        case softSoil
        case hardGroundOrTurf
        case concreteOrRock
        case mildSteelPlate

        /// Critical angle of incidence (measured between bullet trajectory and surface) below which ricochet occurs.
        public var criticalAngle: Measurement<UnitAngle> {
            switch self {
            case .water:
                return Measurement(value: 5.0, unit: .degrees)
            case .softSoil:
                return Measurement(value: 10.0, unit: .degrees)
            case .hardGroundOrTurf:
                return Measurement(value: 15.0, unit: .degrees)
            case .concreteOrRock:
                return Measurement(value: 20.0, unit: .degrees)
            case .mildSteelPlate:
                return Measurement(value: 25.0, unit: .degrees)
            }
        }

        /// Typical retained velocity ratio (V_after / V_before) upon ricochet at shallow angle.
        public var retainedVelocityRatio: Double {
            switch self {
            case .water: return 0.70
            case .softSoil: return 0.40
            case .hardGroundOrTurf: return 0.55
            case .concreteOrRock: return 0.65
            case .mildSteelPlate: return 0.75
            }
        }
    }

    /**
     Determines whether a bullet impacting a surface at a given angle will ricochet, and estimates the post-ricochet velocity.

     - Parameters:
       - impactAngle: Angle of incidence relative to the surface plane (e.g. 8°).
       - impactVelocity: Speed of the bullet at impact.
       - surface: Target surface material.
     - Returns: A tuple containing whether ricochet occurs and the estimated residual velocity.
     */
    public static func evaluateRicochet(
        impactAngle: Measurement<UnitAngle>,
        impactVelocity: Measurement<UnitSpeed>,
        surface: RicochetSurface
    ) -> (willRicochet: Bool, residualVelocity: Measurement<UnitSpeed>) {
        let angleDeg = impactAngle.converted(to: .degrees).value
        let critDeg = surface.criticalAngle.converted(to: .degrees).value

        let willRicochet = angleDeg <= critDeg
        let ratio = willRicochet ? surface.retainedVelocityRatio : 0.0
        let resSpeed = impactVelocity * ratio

        return (willRicochet, resSpeed)
    }

    /**
     Computes the absolute maximum range ($R_{\text{max}}$) of a projectile and the optimal firing angle.

     Under aerodynamic drag, the maximum range is achieved not at 45° (vacuum theory),
     but typically between 30° and 36°. This function optimizes the launch angle to determine the
     outer safety template perimeter for shooting range certification and danger fan mapping.
     */
    public static func calculateMaximumRange(
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        initialVelocity: Measurement<UnitSpeed>,
        weight: Measurement<UnitMass> = Measurement(value: 175, unit: .grains),
        atmosphere: Atmosphere? = nil
    ) -> MaximumRangeResult {
        let soundSpeedFPS = atmosphere?.speedOfSound.converted(to: .feetPerSecond).value ?? Drag.defaultSpeedOfSoundFPS
        let envDragCoeff = atmosphere?.adjustCoefficient(dragCoefficient: dragCoefficient) ?? dragCoefficient
        let v0FPS = initialVelocity.converted(to: .feetPerSecond).value

        // Coarse to fine search over launch angles from 25° to 45°
        var bestAngle = 33.0
        var bestRangeFeet = 0.0
        var bestApogeeFeet = 0.0
        var bestTime = 0.0
        var bestTermVel = 0.0

        let testAngles = [25.0, 28.0, 30.0, 32.0, 34.0, 36.0, 38.0, 40.0, 42.0, 45.0]

        for angleDeg in testAngles {
            let res = simulateArc(
                angleDeg: angleDeg,
                v0FPS: v0FPS,
                dragFunction: dragFunction,
                dragCoeff: envDragCoeff,
                soundSpeedFPS: soundSpeedFPS
            )
            if res.rangeFeet > bestRangeFeet {
                bestRangeFeet = res.rangeFeet
                bestAngle = angleDeg
                bestApogeeFeet = res.apogeeFeet
                bestTime = res.flightTime
                bestTermVel = res.terminalVelocityFPS
            }
        }

        // Refine angle ± 2 degrees with 0.5° resolution
        for delta in stride(from: -2.0, through: 2.0, by: 0.5) {
            let fineAngle = bestAngle + delta
            let res = simulateArc(
                angleDeg: fineAngle,
                v0FPS: v0FPS,
                dragFunction: dragFunction,
                dragCoeff: envDragCoeff,
                soundSpeedFPS: soundSpeedFPS
            )
            if res.rangeFeet > bestRangeFeet {
                bestRangeFeet = res.rangeFeet
                bestAngle = fineAngle
                bestApogeeFeet = res.apogeeFeet
                bestTime = res.flightTime
                bestTermVel = res.terminalVelocityFPS
            }
        }

        return MaximumRangeResult(
            maximumRange: Measurement(value: bestRangeFeet, unit: .feet),
            optimalLaunchAngle: Measurement(value: bestAngle, unit: .degrees),
            vertexAltitude: Measurement(value: bestApogeeFeet, unit: .feet),
            totalFlightTime: Measurement(value: bestTime, unit: .seconds),
            terminalVelocity: Measurement(value: bestTermVel, unit: .feetPerSecond)
        )
    }

    private struct ArcResult {
        var rangeFeet: Double
        var apogeeFeet: Double
        var flightTime: Double
        var terminalVelocityFPS: Double
    }

    private static func simulateArc(
        angleDeg: Double,
        v0FPS: Double,
        dragFunction: DragFunction,
        dragCoeff: Double,
        soundSpeedFPS: Double
    ) -> ArcResult {
        let rad = Math.degToRad(angleDeg)
        var x = 0.0
        var y = 0.0
        var vx = v0FPS * cos(rad)
        var vy = v0FPS * sin(rad)
        var t = 0.0
        var maxApogee = 0.0

        let dt = 0.05
        let g = 32.17405

        while t < 120.0 {
            let v = sqrt(vx * vx + vy * vy)
            if v < 10.0 { break }

            let aDrag = Drag.retard(
                dragFunction: dragFunction,
                dragCoefficient: dragCoeff,
                projectileVelocity: v,
                speedOfSoundFPS: soundSpeedFPS
            )

            let ax = -aDrag * (vx / v)
            let ay = -g - aDrag * (vy / v)

            x += vx * dt
            y += vy * dt
            vx += ax * dt
            vy += ay * dt
            t += dt

            if y > maxApogee {
                maxApogee = y
            }

            if y < 0.0 && t > 0.5 {
                break
            }
        }

        let termV = sqrt(vx * vx + vy * vy)
        return ArcResult(
            rangeFeet: x,
            apogeeFeet: maxApogee,
            flightTime: t,
            terminalVelocityFPS: termV
        )
    }
}
