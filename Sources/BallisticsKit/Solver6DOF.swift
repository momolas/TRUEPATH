//
//  Solver6DOF.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import simd

/// High-fidelity 6-DOF (6 Degrees of Freedom) rigid-body trajectory solver following STANAG 4355 / McCoy standards.
///
/// Integrates 3D translational dynamics coupled with 3D rotational dynamics (spin decay, dynamic yaw of repose,
/// gyroscopic stability Sg, and Magnus forces) using 4th-order Runge-Kutta (RK4) numerical integration.
public struct Solver6DOF: Sendable {

    public struct Derivatives: Sendable {
        public var velocity: simd_double3      // dx, dy, dz (ft/s)
        public var acceleration: simd_double3  // dvx, dvy, dvz (ft/s^2)
        public var dp: Double
        public var droll: Double

        // Backward-compatible scalar accessors
        public var dx: Double {
            get { velocity.x }
            set { velocity.x = newValue }
        }
        public var dy: Double {
            get { velocity.y }
            set { velocity.y = newValue }
        }
        public var dz: Double {
            get { velocity.z }
            set { velocity.z = newValue }
        }
        public var dvx: Double {
            get { acceleration.x }
            set { acceleration.x = newValue }
        }
        public var dvy: Double {
            get { acceleration.y }
            set { acceleration.y = newValue }
        }
        public var dvz: Double {
            get { acceleration.z }
            set { acceleration.z = newValue }
        }

        public init(
            dx: Double,
            dy: Double,
            dz: Double,
            dvx: Double,
            dvy: Double,
            dvz: Double,
            dp: Double,
            droll: Double
        ) {
            self.velocity = simd_double3(dx, dy, dz)
            self.acceleration = simd_double3(dvx, dvy, dvz)
            self.dp = dp
            self.droll = droll
        }

        public init(
            velocity: simd_double3,
            acceleration: simd_double3,
            dp: Double,
            droll: Double
        ) {
            self.velocity = velocity
            self.acceleration = acceleration
            self.dp = dp
            self.droll = droll
        }
    }

    /**
     Solves the 6-DOF rigid-body trajectory integrating translational forces and rotational dynamics.
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
        preferredDistanceUnit: UnitLength = .yards
    ) -> Ballistics {

        var ballistics = Ballistics(
            preferredDistanceUnit: preferredDistanceUnit,
            distanceStep: distanceStep
        )

        let stepInPreferred = distanceStep.converted(to: preferredDistanceUnit)
        let stepFeet = stepInPreferred.converted(to: .feet).value
        let maxFeet = Double(Constants.BALLISTICS_COMPUTATION_MAX_YARDS) * 3.0

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

        // Initial State
        var state = State6DOF(
            x: 0,
            y: initialYFeet,
            z: 0,
            vx: v0FPS * cos(totalElevationAngleRad),
            vy: v0FPS * sin(totalElevationAngleRad),
            vz: 0,
            pitch: totalElevationAngleRad,
            yaw: 0,
            roll: 0,
            p: initialP,
            q: 0,
            r: 0
        )

        let mass = properties.massSlugs
        let diamFeet = properties.diameter.converted(to: .inches).value / 12.0
        let area = properties.referenceAreaSquareFeet
        let ix = properties.axialInertia
        let iy = properties.transverseInertia

        // Compute STANAG 4355 6-DOF differential rates (Accelerated with Apple SIMD)
        func computeDerivatives(s: State6DOF) -> (derivs: Derivatives, sg: Double, sd: Double, yawRepose: Double) {
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

            // Accelerations: vector sum divided by mass
            let accel = (fDrag + fLift + fMag + fGrav) / mass

            // 5. Spin Damping (Roll rate deceleration): dp/dt = (q * S * d^2 * Clp * (p * d / 2w)) / Ix
            let dp = (qDyn * area * diamFeet * diamFeet * clp * (s.p * diamFeet / (2.0 * wMag))) / max(1e-9, ix)

            let derivs = Derivatives(
                velocity: s.velocity,
                acceleration: accel,
                dp: dp,
                droll: s.p
            )

            return (derivs, sg, sd, yawReposeMag)
        }

        func stepRK4(s: State6DOF, dt: Double) -> State6DOF {
            let (k1, _, _, _) = computeDerivatives(s: s)

            let s2 = State6DOF(
                position: s.position + 0.5 * dt * k1.velocity,
                velocity: s.velocity + 0.5 * dt * k1.acceleration,
                pitch: s.pitch,
                yaw: s.yaw,
                roll: s.roll + 0.5 * dt * k1.droll,
                p: s.p + 0.5 * dt * k1.dp,
                q: s.q,
                r: s.r
            )
            let (k2, _, _, _) = computeDerivatives(s: s2)

            let s3 = State6DOF(
                position: s.position + 0.5 * dt * k2.velocity,
                velocity: s.velocity + 0.5 * dt * k2.acceleration,
                pitch: s.pitch,
                yaw: s.yaw,
                roll: s.roll + 0.5 * dt * k2.droll,
                p: s.p + 0.5 * dt * k2.dp,
                q: s.q,
                r: s.r
            )
            let (k3, _, _, _) = computeDerivatives(s: s3)

            let s4 = State6DOF(
                position: s.position + dt * k3.velocity,
                velocity: s.velocity + dt * k3.acceleration,
                pitch: s.pitch,
                yaw: s.yaw,
                roll: s.roll + dt * k3.droll,
                p: s.p + dt * k3.dp,
                q: s.q,
                r: s.r
            )
            let (k4, _, _, _) = computeDerivatives(s: s4)

            let dt6 = dt / 6.0
            return State6DOF(
                position: s.position + dt6 * (k1.velocity + 2.0 * k2.velocity + 2.0 * k3.velocity + k4.velocity),
                velocity: s.velocity + dt6 * (k1.acceleration + 2.0 * k2.acceleration + 2.0 * k3.acceleration + k4.acceleration),
                pitch: s.pitch,
                yaw: s.yaw,
                roll: s.roll + dt6 * (k1.droll + 2.0 * k2.droll + 2.0 * k3.droll + k4.droll),
                p: s.p + dt6 * (k1.dp + 2.0 * k2.dp + 2.0 * k3.dp + k4.dp),
                q: s.q,
                r: s.r
            )
        }

        var sampleIndex = 0
        var nextSampleFeet = Double(sampleIndex) * stepFeet
        var t = 0.0

        func emitPoint(s: State6DOF, elapsed: Double, xReportFeet: Double) {
            let pathInches = s.y * 12.0
            let moaDrop = -Math.radToMOA(atan(s.y / max(xReportFeet, 1e-9)))
            let windageInches = -s.z * 12.0
            let moaWindage = Math.radToMOA(atan((windageInches / 12.0) / max(xReportFeet, 1e-9)))
            let v = s.totalSpeedFPS
            let weightGrains = properties.weight.converted(to: .grains).value
            let ftlbs = weightGrains * (pow(v, 2)) / (2.0 * 32.163 * 7000.0)

            let duration = Measurement(value: elapsed, unit: UnitDuration.seconds)
            let rangeMeasurement = Measurement(value: Double(sampleIndex) * stepInPreferred.value, unit: ballistics.preferredDistanceUnit)

            let (_, sg, sd, yawRepose) = computeDerivatives(s: s)

            let point = Point(
                range: rangeMeasurement,
                drop: Measurement(value: pathInches, unit: .inches),
                dropCorrection: Measurement(value: moaDrop, unit: .minutesOfAngle),
                windage: Measurement(value: windageInches, unit: .inches),
                windageCorrection: Measurement(value: moaWindage, unit: .minutesOfAngle),
                travelTime: duration,
                velocity: Measurement(value: v, unit: .feetPerSecond),
                velocityX: Measurement(value: s.vx, unit: .feetPerSecond),
                velocityY: Measurement(value: s.vy, unit: .feetPerSecond),
                energy: Measurement(value: ftlbs, unit: .footPounds),
                spinDrift: Measurement(value: windageInches, unit: .inches),
                coriolisHorizontal: nil,
                coriolisVertical: nil,
                spinRateRPM: s.spinRateRPM,
                stabilityFactorSg: sg,
                dynamicStabilitySd: sd,
                yawOfReposeAngle: Measurement(value: yawRepose, unit: .radians)
            )

            ballistics.distances.append(point)
        }

        emitPoint(s: state, elapsed: t, xReportFeet: 0)
        sampleIndex += 1
        nextSampleFeet = Double(sampleIndex) * stepFeet

        while true {
            let v = max(10.0, state.totalSpeedFPS)
            let dt = 15.0 / v

            let nextState = stepRK4(s: state, dt: dt)

            while nextState.x >= nextSampleFeet {
                let alpha = (nextSampleFeet - state.x) / max(1e-9, nextState.x - state.x)
                let interpState = State6DOF(
                    x: nextSampleFeet,
                    y: state.y + alpha * (nextState.y - state.y),
                    z: state.z + alpha * (nextState.z - state.z),
                    vx: state.vx + alpha * (nextState.vx - state.vx),
                    vy: state.vy + alpha * (nextState.vy - state.vy),
                    vz: state.vz + alpha * (nextState.vz - state.vz),
                    pitch: state.pitch,
                    yaw: state.yaw,
                    roll: state.roll + alpha * (nextState.roll - state.roll),
                    p: state.p + alpha * (nextState.p - state.p),
                    q: state.q,
                    r: state.r
                )
                let tInterp = t + alpha * dt
                emitPoint(s: interpState, elapsed: tInterp, xReportFeet: nextSampleFeet)

                sampleIndex += 1
                nextSampleFeet = Double(sampleIndex) * stepFeet
                if nextSampleFeet > maxFeet { break }
            }

            state = nextState
            t += dt

            if state.x >= maxFeet || state.vx <= 50.0 || nextState.vx <= 50.0 || nextSampleFeet > maxFeet {
                break
            }
        }

        return ballistics
    }
}
