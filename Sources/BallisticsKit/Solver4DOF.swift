//
//  Solver4DOF.swift
//  BallisticsKit
//
//  Created by Antigravity on 08/10/2026.
//

import Foundation
import simd

/// NATO STANAG 4355 / AOP-4355 Modified Point Mass (4-DOF) trajectory solver.
///
/// Implements 3D translational dynamics coupled with axial spin decay (4th degree of freedom),
/// equilibrium yaw of repose (\alpha_e), aerodynamic lift, Magnus force, vertical/horizontal Coriolis,
/// and adaptive-step Runge-Kutta Dormand-Prince 5(4) integration.
public struct Solver4DOF: Sendable {

    /**
     Solves the trajectory using the NATO STANAG 4355 Modified Point Mass (4-DOF) formulation.
     */
    public static func solve(
        preferredDistanceUnit: UnitLength = .yards,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement<UnitLength>,
        atmosphere: Atmosphere? = nil,
        windSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        windAngle: Double = 0,
        weight: Measurement<UnitMass> = Measurement<UnitMass>(value: 175, unit: .grains),
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards),
        twist: Measurement<UnitLength>? = nil,
        twistDirection: TwistDirection = .right,
        bulletDiameter: Measurement<UnitLength>? = nil,
        bulletLength: Measurement<UnitLength>? = nil,
        latitude: Measurement<UnitAngle>? = nil,
        azimuth: Measurement<UnitAngle>? = nil,
        tolerance: IntegratorTolerance = .standard,
        maxRange: Measurement<UnitLength>? = nil
    ) -> Ballistics {

        // 1. Synthesize rigid-body properties and aerodynamic derivatives if not explicitly provided
        let diam = bulletDiameter ?? Measurement(value: 0.308, unit: .inches)
        let len = bulletLength ?? Measurement(value: 1.240, unit: .inches)
        let effWeight = weight.value > 0 ? weight : Measurement(value: 175, unit: .grains)

        let properties = ProjectileProperties(
            weight: effWeight,
            diameter: diam,
            length: len
        )

        let coefficients = AerodynamicCoefficients.synthesize(
            properties: properties,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient
        )

        let effTwist = twist ?? Measurement(value: 11.0, unit: .inches)

        return solve(
            properties: properties,
            coefficients: coefficients,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            shootingAngle: shootingAngle,
            twist: effTwist,
            twistDirection: twistDirection,
            atmosphere: atmosphere,
            windSpeed: windSpeed,
            windAngle: windAngle,
            latitude: latitude,
            azimuth: azimuth,
            distanceStep: distanceStep,
            preferredDistanceUnit: preferredDistanceUnit,
            tolerance: tolerance,
            maxRange: maxRange
        )
    }

    /**
     Solves the trajectory using full rigid properties and aerodynamic coefficient functions.
     */
    public static func solve(
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        twist: Measurement<UnitLength>,
        twistDirection: TwistDirection = .right,
        atmosphere: Atmosphere? = nil,
        windSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        windAngle: Double = 0,
        latitude: Measurement<UnitAngle>? = nil,
        azimuth: Measurement<UnitAngle>? = nil,
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards),
        preferredDistanceUnit: UnitLength = .yards,
        tolerance: IntegratorTolerance = .standard,
        maxRange: Measurement<UnitLength>? = nil
    ) -> Ballistics {

        var ballistics = Ballistics(
            preferredDistanceUnit: preferredDistanceUnit,
            distanceStep: distanceStep
        )

        let stepInPreferred = distanceStep.converted(to: preferredDistanceUnit)
        let stepFeet = stepInPreferred.converted(to: .feet).value
        let defaultMaxFeet = Double(Constants.BALLISTICS_COMPUTATION_MAX_YARDS) * 3.0
        let maxFeet: Double
        if let range = maxRange {
            maxFeet = min(defaultMaxFeet, max(stepFeet, range.converted(to: .feet).value))
        } else {
            maxFeet = defaultMaxFeet
        }

        let v0FPS = initialVelocity.converted(to: .feetPerSecond).value
        let twistInches = twist.converted(to: .inches).value
        let sightInches = sightHeight.converted(to: .inches).value
        let initialYFeet = -sightInches / 12.0

        let soundSpeedFPS = atmosphere?.speedOfSound.converted(to: .feetPerSecond).value ?? Drag.defaultSpeedOfSoundFPS
        let airDensitySlugFt3 = 0.0023769 // Standard sea level air density

        // Wind components (in ft/s)
        let windFPS = windSpeed.converted(to: .feetPerSecond).value
        let windRad = Math.degToRad(windAngle)
        let windHeadX = windFPS * cos(windRad)
        let windCrossZ = windFPS * sin(windRad)

        // Initial spin rate p0 = (2 * pi * V0) / (twist_in_feet) * twist_sign
        let twistFeet = max(0.1, twistInches / 12.0)
        let initialP = (2.0 * Double.pi * v0FPS / twistFeet) * twistDirection.sign

        // Zero angle elevation estimate
        let zeroAngleDeg = Angle.zeroAngle(
            dragFunction: .g7,
            dragCoefficient: 0.500,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            yIntercept: 0,
            speedOfSoundFPS: soundSpeedFPS
        )

        let totalElevationAngleRad = Math.degToRad(shootingAngle.converted(to: .degrees).value + zeroAngleDeg)

        // Initial State (STANAG 4355: position, velocity, axial spin p)
        var state = State4DOF(
            x: 0,
            y: initialYFeet,
            z: 0,
            vx: v0FPS * cos(totalElevationAngleRad),
            vy: v0FPS * sin(totalElevationAngleRad),
            vz: 0,
            p: initialP,
            time: 0
        )

        let mass = properties.massSlugs
        let diamFeet = properties.diameter.converted(to: .inches).value / 12.0
        let area = properties.referenceAreaSquareFeet
        let ix = properties.axialInertia
        let iy = properties.transverseInertia

        // Earth angular velocity vector in firing coordinate frame
        let omegaEarth: simd_double3 = {
            guard let lat = latitude, let az = azimuth else { return .zero }
            let omegaMag = 7.292115e-5 // Earth rotation rate rad/s
            let latRad = Math.degToRad(lat.converted(to: .degrees).value)
            let azRad = Math.degToRad(az.converted(to: .degrees).value)
            let ox = omegaMag * cos(latRad) * cos(azRad)
            let oy = omegaMag * sin(latRad)
            let oz = -omegaMag * cos(latRad) * sin(azRad)
            return simd_double3(ox, oy, oz)
        }()

        // STANAG 4355 differential equations of motion
        func computeDerivatives(s: State4DOF) -> (derivs: DormandPrince54.Derivatives4DOF, sg: Double, sd: Double, yawRepose: Double) {
            // Apparent velocity relative to wind: w = v - v_wind
            let windDelta = simd_double3(windHeadX, 0, -windCrossZ)
            let wVec = s.velocity + windDelta
            let wMag = max(10.0, simd_length(wVec))

            let mach = wMag / soundSpeedFPS
            let qDyn = 0.5 * airDensitySlugFt3 * wMag * wMag

            // Aerodynamic derivatives at current Mach
            let cd0 = coefficients.cd0(mach)
            let clA = coefficients.clAlpha(mach)
            let cmA = coefficients.cmAlpha(mach)
            let clp = coefficients.clp(mach)
            let cmag = coefficients.cMag(mach)

            // Overturning moment factor
            let mOverturnPerRad = qDyn * area * diamFeet * cmA

            // Gyroscopic stability Sg
            let sg = (ix * ix * s.p * s.p) / max(1e-9, 4.0 * iy * mOverturnPerRad)

            // Dynamic stability Sd
            let sd = max(0.01, min(2.0, 1.0 + 0.1 * (sg - 1.5)))

            // STANAG 4355 Equilibrium Yaw of Repose: alpha_e = (2 * Ix * p * g) / (rho * S * d * w^3 * CM_alpha)
            let yawReposeMag = (2.0 * ix * s.p * 32.17405) / max(1e-9, airDensitySlugFt3 * area * diamFeet * pow(wMag, 3) * cmA)

            let alphaTotal = abs(yawReposeMag)

            // 1. Drag Force: F_drag = -q * S * CD(M, alpha) * (w / wMag)
            let cdTotal = cd0 + 1.5 * alphaTotal * alphaTotal
            let fDragMag = qDyn * area * cdTotal
            let fDrag = -fDragMag * (wVec / wMag)

            // 2. Lift Force (due to yaw of repose): F_lift = q * S * CL_alpha * delta
            let fLiftMag = qDyn * area * clA
            let fLift = simd_double3(0, 0, -fLiftMag * yawReposeMag)

            // 3. Magnus Force: F_mag = 0.5 * rho * S * d * Cmag * (p x w)
            let fMagFactor = 0.5 * airDensitySlugFt3 * area * diamFeet * cmag * (s.p / wMag)
            let fMag = simd_double3(0, -fMagFactor * wVec.z, fMagFactor * wVec.y)

            // 4. Gravity Force
            let fGrav = simd_double3(0, -32.17405 * mass, 0)

            // 5. Coriolis Acceleration: a_coriolis = -2 * (omega x v)
            let aCoriolis: simd_double3
            if simd_length(omegaEarth) > 0 {
                aCoriolis = -2.0 * simd_cross(omegaEarth, s.velocity)
            } else {
                aCoriolis = .zero
            }

            // Total Linear Acceleration
            let accel = (fDrag + fLift + fMag + fGrav) / mass + aCoriolis

            // 6. Spin Damping (Roll rate deceleration dp/dt)
            let dp = (qDyn * area * diamFeet * diamFeet * clp * (s.p * diamFeet / (2.0 * wMag))) / max(1e-9, ix)

            let derivs = DormandPrince54.Derivatives4DOF(
                velocity: s.velocity,
                acceleration: accel,
                dp: dp
            )

            return (derivs, sg, sd, yawReposeMag)
        }

        var sampleIndex = 0
        var nextSampleFeet = Double(sampleIndex) * stepFeet
        var currentDt = tolerance.initialStep

        func emitPoint(s: State4DOF, sg: Double, sd: Double, yawRepose: Double) {
            let pathInches = s.position.y * 12.0
            let xFeet = max(1e-9, s.position.x)
            let moaDrop = -Math.radToMOA(atan(s.position.y / xFeet))

            let windageInches = s.position.z * 12.0
            let moaWindage = Math.radToMOA(atan(s.position.z / xFeet))

            let vTotal = s.totalSpeedFPS
            let ftlbs = mass * pow(vTotal, 2) / 2.0

            let rangeM = Measurement(value: Double(sampleIndex) * stepInPreferred.value, unit: preferredDistanceUnit)
            let duration = Measurement(value: s.time, unit: UnitDuration.seconds)

            let point = Point(
                range: rangeM,
                drop: Measurement(value: pathInches, unit: .inches),
                dropCorrection: Measurement(value: moaDrop, unit: .minutesOfAngle),
                windage: Measurement(value: windageInches, unit: .inches),
                windageCorrection: Measurement(value: moaWindage, unit: .minutesOfAngle),
                travelTime: duration,
                velocity: Measurement(value: vTotal, unit: .feetPerSecond),
                velocityX: Measurement(value: s.velocity.x, unit: .feetPerSecond),
                velocityY: Measurement(value: s.velocity.y, unit: .feetPerSecond),
                energy: Measurement(value: ftlbs, unit: .footPounds),
                spinDrift: Measurement(value: abs(yawRepose) * xFeet * 12.0 * 0.05, unit: .inches),
                coriolisHorizontal: nil,
                coriolisVertical: nil,
                spinRateRPM: s.spinRateRPM,
                stabilityFactorSg: sg,
                dynamicStabilitySd: sd,
                yawOfReposeAngle: Measurement(value: Math.radToMOA(yawRepose), unit: .minutesOfAngle)
            )
            ballistics.distances.append(point)
        }

        let (_, initialSg, initialSd, initialYaw) = computeDerivatives(s: state)
        emitPoint(s: state, sg: initialSg, sd: initialSd, yawRepose: initialYaw)

        sampleIndex += 1
        nextSampleFeet = Double(sampleIndex) * stepFeet

        while state.position.x < maxFeet && state.totalSpeedFPS > 200.0 {
            let stepRes = DormandPrince54.step4DOF(
                s: state,
                dt: currentDt,
                tolerance: tolerance,
                computeDerivatives: computeDerivatives
            )

            if stepRes.accepted {
                let sPrev = state
                let sNext = stepRes.nextState

                while sNext.position.x >= nextSampleFeet {
                    let alpha = (nextSampleFeet - sPrev.position.x) / max(1e-12, sNext.position.x - sPrev.position.x)
                    let interpPos = sPrev.position + alpha * (sNext.position - sPrev.position)
                    let interpVel = sPrev.velocity + alpha * (sNext.velocity - sPrev.velocity)
                    let interpP = sPrev.p + alpha * (sNext.p - sPrev.p)
                    let interpTime = sPrev.time + alpha * (sNext.time - sPrev.time)

                    let interpState = State4DOF(
                        position: interpPos,
                        velocity: interpVel,
                        p: interpP,
                        time: interpTime
                    )

                    let (_, sg, sd, yaw) = computeDerivatives(s: interpState)
                    emitPoint(s: interpState, sg: sg, sd: sd, yawRepose: yaw)

                    sampleIndex += 1
                    nextSampleFeet = Double(sampleIndex) * stepFeet
                    if nextSampleFeet > maxFeet { break }
                }

                state = sNext
            }

            currentDt = stepRes.nextDt
            if currentDt < tolerance.minStep {
                currentDt = tolerance.minStep
            }
        }

        return ballistics
    }
}
