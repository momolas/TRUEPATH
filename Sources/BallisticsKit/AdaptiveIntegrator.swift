//
//  AdaptiveIntegrator.swift
//  BallisticsKit
//
//  Created by Antigravity on 02/10/2026.
//

import Foundation
import simd

/// Numerical tolerance settings for adaptive-step Runge-Kutta integrators (Dormand-Prince 5(4) / RKF45).
public struct IntegratorTolerance: Sendable, Equatable, Hashable {
    /// Absolute error tolerance for state vector components (in native units: ft, ft/s, rad/s).
    public var absoluteTolerance: Double

    /// Relative error tolerance for state vector components.
    public var relativeTolerance: Double

    /// Minimum allowable integration time step in seconds (prevents infinite stalling near singularities).
    public var minStep: Double

    /// Maximum allowable integration time step in seconds (prevents overshooting sampling intervals).
    public var maxStep: Double

    /// Initial starting time step in seconds.
    public var initialStep: Double

    /// Safety factor for step size adaptation (typically 0.85 to 0.90).
    public var safetyFactor: Double

    public init(
        absoluteTolerance: Double = 1e-4,
        relativeTolerance: Double = 1e-4,
        minStep: Double = 1e-5,
        maxStep: Double = 0.02,
        initialStep: Double = 0.002,
        safetyFactor: Double = 0.90
    ) {
        self.absoluteTolerance = absoluteTolerance
        self.relativeTolerance = relativeTolerance
        self.minStep = minStep
        self.maxStep = maxStep
        self.initialStep = initialStep
        self.safetyFactor = safetyFactor
    }

    /// Standard tolerance configuration for general high-precision trajectory calculation.
    public static let standard = IntegratorTolerance()

    /// High-precision tolerance configuration for Extreme Long Range (ELR) and scientific simulation.
    public static let highPrecision = IntegratorTolerance(
        absoluteTolerance: 1e-8,
        relativeTolerance: 1e-7,
        minStep: 1e-7,
        maxStep: 0.005,
        initialStep: 0.0005,
        safetyFactor: 0.92
    )

    /// Fast tolerance configuration for real-time mobile HUD or low-power rendering.
    public static let fast = IntegratorTolerance(
        absoluteTolerance: 1e-4,
        relativeTolerance: 1e-3,
        minStep: 1e-5,
        maxStep: 0.02,
        initialStep: 0.002,
        safetyFactor: 0.85
    )
}

/// Implementation of the embedded Dormand-Prince 5(4) (DOPRI5) adaptive Runge-Kutta integrator.
///
/// Features 7 stages with the First-Same-As-Last (FSAL) property, providing an $O(dt^5)$ primary solution
/// and an embedded $O(dt^4)$ error estimate for step size regulation.
public struct DormandPrince54: Sendable {

    // MARK: - Butcher Tableau Coefficients (Dormand-Prince 5(4))
    // a_ij matrix
    public static let a21 = 1.0 / 5.0

    public static let a31 = 3.0 / 40.0
    public static let a32 = 9.0 / 40.0

    public static let a41 = 44.0 / 45.0
    public static let a42 = -56.0 / 15.0
    public static let a43 = 32.0 / 9.0

    public static let a51 = 19372.0 / 6561.0
    public static let a52 = -25360.0 / 2187.0
    public static let a53 = 64448.0 / 6561.0
    public static let a54 = -212.0 / 729.0

    public static let a61 = 9017.0 / 3168.0
    public static let a62 = -355.0 / 33.0
    public static let a63 = 46732.0 / 5247.0
    public static let a64 = 49.0 / 176.0
    public static let a65 = -5103.0 / 18656.0

    public static let a71 = 35.0 / 384.0
    public static let a72 = 0.0
    public static let a73 = 500.0 / 1113.0
    public static let a74 = 125.0 / 192.0
    public static let a75 = -2187.0 / 6784.0
    public static let a76 = 11.0 / 84.0

    // 5th-order weights b_i
    public static let b1 = 35.0 / 384.0
    public static let b2 = 0.0
    public static let b3 = 500.0 / 1113.0
    public static let b4 = 125.0 / 192.0
    public static let b5 = -2187.0 / 6784.0
    public static let b6 = 11.0 / 84.0
    public static let b7 = 0.0

    // Error weights e_i = b_i - b_hat_i
    public static let e1 = 71.0 / 57600.0
    public static let e2 = 0.0
    public static let e3 = -71.0 / 16695.0
    public static let e4 = 71.0 / 1920.0
    public static let e5 = -17253.0 / 339200.0
    public static let e6 = 22.0 / 525.0
    public static let e7 = -1.0 / 40.0

    // MARK: - NATO STANAG 4355 (4-DOF Modified Point Mass) Adaptive Step

    public struct Derivatives4DOF: Sendable {
        public var velocity: simd_double3      // dx, dy, dz (ft/s)
        public var acceleration: simd_double3  // dvx, dvy, dvz (ft/s^2)
        public var dp: Double                  // dp/dt (rad/s^2)

        public init(velocity: simd_double3, acceleration: simd_double3, dp: Double) {
            self.velocity = velocity
            self.acceleration = acceleration
            self.dp = dp
        }
    }

    public typealias Derivatives = Derivatives4DOF

    public struct StepResult4DOF: Sendable {
        public var nextState: State4DOF
        public var nextDt: Double
        public var errorRatio: Double
        public var accepted: Bool
        public var k7: Derivatives4DOF
        public var sg: Double
        public var sd: Double
        public var yawRepose: Double

        public init(
            nextState: State4DOF,
            nextDt: Double,
            errorRatio: Double,
            accepted: Bool,
            k7: Derivatives4DOF = Derivatives4DOF(velocity: .zero, acceleration: .zero, dp: 0),
            sg: Double = 1.5,
            sd: Double = 1.0,
            yawRepose: Double = 0.0
        ) {
            self.nextState = nextState
            self.nextDt = nextDt
            self.errorRatio = errorRatio
            self.accepted = accepted
            self.k7 = k7
            self.sg = sg
            self.sd = sd
            self.yawRepose = yawRepose
        }
    }

    public typealias StepResult = StepResult4DOF

    /**
     Executes a single adaptive step for 4-DOF Modified Point Mass (STANAG 4355) using Dormand-Prince 5(4).
     */
    @inlinable
    public static func step(
        s: State4DOF,
        dt: Double,
        tolerance: IntegratorTolerance,
        k1: Derivatives4DOF? = nil,
        computeDerivatives: (State4DOF) -> (derivs: Derivatives4DOF, sg: Double, sd: Double, yawRepose: Double)
    ) -> StepResult4DOF {
        step4DOF(s: s, dt: dt, tolerance: tolerance, k1: k1, computeDerivatives: computeDerivatives)
    }

    /**
     Executes a single adaptive step for 4-DOF Modified Point Mass (STANAG 4355) using Dormand-Prince 5(4).
     Takes advantage of FSAL (First-Same-As-Last) by reusing previous accepted stage 7 derivatives as stage 1.
     */
    public static func step4DOF(
        s: State4DOF,
        dt: Double,
        tolerance: IntegratorTolerance,
        k1: Derivatives4DOF? = nil,
        computeDerivatives: (State4DOF) -> (derivs: Derivatives4DOF, sg: Double, sd: Double, yawRepose: Double)
    ) -> StepResult4DOF {
        // Stage 1: Evaluate if not provided via FSAL (First-Same-As-Last)
        let k1Derivs: Derivatives4DOF
        if let passedK1 = k1 {
            k1Derivs = passedK1
        } else {
            k1Derivs = computeDerivatives(s).derivs
        }

        // Stage 2
        let s2 = State4DOF(
            position: s.position + (dt * a21) * k1Derivs.velocity,
            velocity: s.velocity + (dt * a21) * k1Derivs.acceleration,
            p: s.p + (dt * a21) * k1Derivs.dp,
            time: s.time + dt * a21
        )
        let (k2, _, _, _) = computeDerivatives(s2)

        // Stage 3
        let s3 = State4DOF(
            position: s.position + dt * (a31 * k1Derivs.velocity + a32 * k2.velocity),
            velocity: s.velocity + dt * (a31 * k1Derivs.acceleration + a32 * k2.acceleration),
            p: s.p + dt * (a31 * k1Derivs.dp + a32 * k2.dp),
            time: s.time + dt * (a31 + a32)
        )
        let (k3, _, _, _) = computeDerivatives(s3)

        // Stage 4
        let s4 = State4DOF(
            position: s.position + dt * (a41 * k1Derivs.velocity + a42 * k2.velocity + a43 * k3.velocity),
            velocity: s.velocity + dt * (a41 * k1Derivs.acceleration + a42 * k2.acceleration + a43 * k3.acceleration),
            p: s.p + dt * (a41 * k1Derivs.dp + a42 * k2.dp + a43 * k3.dp),
            time: s.time + dt * (a41 + a42 + a43)
        )
        let (k4, _, _, _) = computeDerivatives(s4)

        // Stage 5
        let s5 = State4DOF(
            position: s.position + dt * (a51 * k1Derivs.velocity + a52 * k2.velocity + a53 * k3.velocity + a54 * k4.velocity),
            velocity: s.velocity + dt * (a51 * k1Derivs.acceleration + a52 * k2.acceleration + a53 * k3.acceleration + a54 * k4.acceleration),
            p: s.p + dt * (a51 * k1Derivs.dp + a52 * k2.dp + a53 * k3.dp + a54 * k4.dp),
            time: s.time + dt * (a51 + a52 + a53 + a54)
        )
        let (k5, _, _, _) = computeDerivatives(s5)

        // Stage 6
        let s6 = State4DOF(
            position: s.position + dt * (a61 * k1Derivs.velocity + a62 * k2.velocity + a63 * k3.velocity + a64 * k4.velocity + a65 * k5.velocity),
            velocity: s.velocity + dt * (a61 * k1Derivs.acceleration + a62 * k2.acceleration + a63 * k3.acceleration + a64 * k4.acceleration + a65 * k5.acceleration),
            p: s.p + dt * (a61 * k1Derivs.dp + a62 * k2.dp + a63 * k3.dp + a64 * k4.dp + a65 * k5.dp),
            time: s.time + dt * (a61 + a62 + a63 + a64 + a65)
        )
        let (k6, _, _, _) = computeDerivatives(s6)

        // 5th-order primary state estimate
        let pos5 = s.position + dt * (b1 * k1Derivs.velocity + b3 * k3.velocity + b4 * k4.velocity + b5 * k5.velocity + b6 * k6.velocity)
        let vel5 = s.velocity + dt * (b1 * k1Derivs.acceleration + b3 * k3.acceleration + b4 * k4.acceleration + b5 * k5.acceleration + b6 * k6.acceleration)
        let p5 = s.p + dt * (b1 * k1Derivs.dp + b3 * k3.dp + b4 * k4.dp + b5 * k5.dp + b6 * k6.dp)

        let candidateState = State4DOF(
            position: pos5,
            velocity: vel5,
            p: p5,
            time: s.time + dt
        )

        // Stage 7 (FSAL evaluation at candidate state)
        let (k7, sg7, sd7, yaw7) = computeDerivatives(candidateState)

        // Error vector estimate E = y_5 - y_4 = dt * sum(e_i * k_i)
        let errPosVec = dt * (e1 * k1Derivs.velocity + e3 * k3.velocity + e4 * k4.velocity + e5 * k5.velocity + e6 * k6.velocity + e7 * k7.velocity)
        let errVelVec = dt * (e1 * k1Derivs.acceleration + e3 * k3.acceleration + e4 * k4.acceleration + e5 * k5.acceleration + e6 * k6.acceleration + e7 * k7.acceleration)

        let posNorm = simd_length(pos5)
        let velNorm = simd_length(vel5)

        let posTol = tolerance.absoluteTolerance + tolerance.relativeTolerance * posNorm
        let velTol = tolerance.absoluteTolerance + tolerance.relativeTolerance * velNorm

        let errPos = simd_length(errPosVec) / max(1e-12, posTol)
        let errVel = simd_length(errVelVec) / max(1e-12, velTol)

        let errorRatio = max(errPos, errVel)
        let accepted = errorRatio <= 1.0

        let factor: Double
        if accepted {
            if errorRatio < 1e-10 {
                factor = 2.0
            } else {
                let sFactor = tolerance.safetyFactor * pow(errorRatio, -0.2)
                factor = min(2.0, max(0.2, sFactor))
            }
        } else {
            let sFactor = tolerance.safetyFactor * pow(errorRatio, -0.25)
            factor = min(0.9, max(0.1, sFactor))
        }

        let rawNextDt = dt * factor
        let clampedNextDt = min(tolerance.maxStep, max(tolerance.minStep, rawNextDt))

        return StepResult4DOF(
            nextState: candidateState,
            nextDt: clampedNextDt,
            errorRatio: errorRatio,
            accepted: accepted,
            k7: k7,
            sg: sg7,
            sd: sd7,
            yawRepose: yaw7
        )
    }
}
