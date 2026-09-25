//
//  AerodynamicCoefficients.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Encapsulates the 6-DOF aerodynamic force and moment derivatives across Mach numbers.
public struct AerodynamicCoefficients: Sendable {

    /// Zero-yaw axial drag coefficient CD0(Mach).
    public let cd0: @Sendable (Double) -> Double

    /// Lift / normal force derivative per radian: CLalpha(Mach).
    public let clAlpha: @Sendable (Double) -> Double

    /// Overturning moment derivative per radian: CMalpha(Mach).
    public let cmAlpha: @Sendable (Double) -> Double

    /// Pitch/yaw damping moment derivative: CMq(Mach).
    public let cmq: @Sendable (Double) -> Double

    /// Roll spin damping moment derivative: Clp(Mach).
    public let clp: @Sendable (Double) -> Double

    /// Magnus force coefficient: Cmag(Mach).
    public let cMag: @Sendable (Double) -> Double

    /// Magnus moment coefficient: CMpa(Mach).
    public let cMpa: @Sendable (Double) -> Double

    public init(
        cd0: @escaping @Sendable (Double) -> Double,
        clAlpha: @escaping @Sendable (Double) -> Double,
        cmAlpha: @escaping @Sendable (Double) -> Double,
        cmq: @escaping @Sendable (Double) -> Double,
        clp: @escaping @Sendable (Double) -> Double,
        cMag: @escaping @Sendable (Double) -> Double,
        cMpa: @escaping @Sendable (Double) -> Double
    ) {
        self.cd0 = cd0
        self.clAlpha = clAlpha
        self.cmAlpha = cmAlpha
        self.cmq = cmq
        self.clp = clp
        self.cMag = cMag
        self.cMpa = cMpa
    }

    /**
     Synthesizes realistic 6-DOF aerodynamic derivatives using the McCoy/BRL semi-empirical formulation
     based on the projectile's geometric dimensions and reference drag function.
     */
    public static func synthesize(
        properties: ProjectileProperties,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double
    ) -> AerodynamicCoefficients {
        let lengthCalibers = properties.length.converted(to: .inches).value / properties.diameter.converted(to: .inches).value
        let noseCalibers = properties.noseLength.converted(to: .inches).value / properties.diameter.converted(to: .inches).value

        return AerodynamicCoefficients(
            cd0: { mach in
                // Standard drag profile scaled by BC
                let baseVelocity = mach * 1116.45
                let retardation = Drag.retard(
                    dragFunction: dragFunction,
                    dragCoefficient: dragCoefficient,
                    projectileVelocity: baseVelocity
                )
                // CD0 ~ retardation / factor
                return max(0.12, (retardation * dragCoefficient) / max(1.0, 0.232847 * baseVelocity))
            },
            clAlpha: { mach in
                // Lift slope increases slightly in supersonic: CL_alpha ~ 2.0 to 2.8 / rad
                if mach > 1.2 {
                    return 2.0 + 0.3 * min(mach, 3.0)
                } else if mach < 0.8 {
                    return 1.8 + 0.15 * lengthCalibers
                } else {
                    return 2.4
                }
            },
            cmAlpha: { mach in
                // Overturning moment slope ~ 2.5 to 4.5 / rad depending on nose length & caliber length
                let baseCM = 0.8 * noseCalibers + 0.4 * lengthCalibers
                if mach > 1.2 {
                    return baseCM * 0.95
                } else {
                    return baseCM
                }
            },
            cmq: { mach in
                // Pitch damping moment derivative ~ -8.0 to -16.0 / rad
                let baseCmq = -3.0 * (lengthCalibers * lengthCalibers) / 4.0
                return min(-5.0, baseCmq)
            },
            clp: { mach in
                // Spin damping moment ~ -0.015 to -0.030 / rad (slows down axial rotation over flight)
                return -0.020 * (1.0 + 0.1 * (lengthCalibers - 3.0))
            },
            cMag: { mach in
                // Magnus force coefficient ~ 0.2 to 0.5 / rad
                return 0.35
            },
            cMpa: { mach in
                // Magnus moment coefficient ~ -0.4 to -1.0 / rad
                return -0.60
            }
        )
    }
}
