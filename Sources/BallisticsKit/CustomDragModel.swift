//
//  CustomDragModel.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents a custom aerodynamic drag model (e.g. from Doppler radar data) with arbitrary Mach vs Cd sample points.
public struct CustomDragModel: Sendable, Equatable, Hashable, Codable {

    /// A single Mach number to drag coefficient (Cd) data point.
    public struct DataPoint: Sendable, Equatable, Hashable, Codable {
        public let mach: Double
        public let cd: Double

        public init(mach: Double, cd: Double) {
            self.mach = mach
            self.cd = cd
        }
    }

    /// The list of measured Mach vs Cd points (sorted in ascending order of Mach number).
    public let dataPoints: [DataPoint]

    public init(dataPoints: [DataPoint]) {
        self.dataPoints = dataPoints.sorted { $0.mach < $1.mach }
    }

    /**
     Interpolates the drag coefficient (Cd) for a given Mach number.
     */
    public func dragCoefficient(atMach mach: Double) -> Double {
        guard !dataPoints.isEmpty else { return 0.3 }

        if mach <= dataPoints.first!.mach {
            return dataPoints.first!.cd
        }
        if mach >= dataPoints.last!.mach {
            return dataPoints.last!.cd
        }

        for i in 0..<(dataPoints.count - 1) {
            let p0 = dataPoints[i]
            let p1 = dataPoints[i + 1]
            if mach >= p0.mach && mach <= p1.mach {
                let factor = (mach - p0.mach) / max(1e-9, p1.mach - p0.mach)
                return p0.cd + factor * (p1.cd - p0.cd)
            }
        }

        return dataPoints.last!.cd
    }

    /**
     Calculates deceleration retardation using this custom drag table.
     */
    public func retard(
        ballisticCoefficient: Double = 1.0,
        projectileVelocity: Double,
        speedOfSoundFPS: Double = 1116.45
    ) -> Double {
        let soundSpeed = max(100.0, speedOfSoundFPS)
        let mach = projectileVelocity / soundSpeed
        let cd = self.dragCoefficient(atMach: mach)
        return (0.232847 * cd * projectileVelocity) / max(1e-6, ballisticCoefficient)
    }
}
