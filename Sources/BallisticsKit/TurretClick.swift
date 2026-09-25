//
//  TurretClick.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents standard optic turret adjustment click increments.
public enum TurretClick: Sendable, Equatable, Hashable {
    /// 1/4 MOA per click (0.25 Minutes of Angle, ~0.26 inch @ 100 yards).
    case oneFourthMOA

    /// 1/8 MOA per click (0.125 Minutes of Angle, ~0.13 inch @ 100 yards).
    case oneEighthMOA

    /// 1/2 MOA per click (0.5 Minutes of Angle, ~0.52 inch @ 100 yards).
    case oneHalfMOA

    /// 0.1 MRAD / MIL per click (1.0 cm @ 100 meters, ~0.36 inch @ 100 yards).
    case pointOneMRAD

    /// 0.05 MRAD / MIL per click (0.5 cm @ 100 meters, ~0.18 inch @ 100 yards).
    case pointZeroFiveMRAD

    /// Custom angular click increment.
    case custom(Measurement<UnitAngle>)

    /// The angular value of a single click.
    public var angleValue: Measurement<UnitAngle> {
        switch self {
        case .oneFourthMOA:
            return Measurement(value: 0.25, unit: .minutesOfAngle)
        case .oneEighthMOA:
            return Measurement(value: 0.125, unit: .minutesOfAngle)
        case .oneHalfMOA:
            return Measurement(value: 0.5, unit: .minutesOfAngle)
        case .pointOneMRAD:
            return Measurement(value: 0.1, unit: .milliradians)
        case .pointZeroFiveMRAD:
            return Measurement(value: 0.05, unit: .milliradians)
        case .custom(let angle):
            return angle
        }
    }

    /**
     Calculates the number of turret clicks required to apply an angular correction.

     - Parameter correction: The angular correction (drop, windage, or total correction).
     - Returns: The rounded integer number of turret clicks.
     */
    public func clicks(for correction: Measurement<UnitAngle>) -> Int {
        let clickRad = angleValue.converted(to: .radians).value
        guard clickRad > 0 else { return 0 }
        let correctionRad = correction.converted(to: .radians).value
        return Int((correctionRad / clickRad).rounded())
    }
}
