//
//  Drag.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

struct Drag {

    // Default standard speed of sound at sea level (59°F / 15°C) in ft/s
    static let defaultSpeedOfSoundFPS: Double = 1116.45

    // Standard atmospheric deceleration factor: PIR * a0 = (PI/8) * (RHO0/144) * a0 = 2.08551e-4 * 1116.45 = 0.232847
    private static let standardDecelerationFactor: Double = 0.232847

    // Standard G2 Mach vs Cd table
    private static let g2MachTable: [(mach: Double, cd: Double)] = [
        (0.00, 0.1500),
        (0.60, 0.1500),
        (0.70, 0.1520),
        (0.80, 0.1600),
        (0.90, 0.2000),
        (0.95, 0.2700),
        (1.00, 0.4400),
        (1.05, 0.4650),
        (1.10, 0.4600),
        (1.20, 0.4400),
        (1.40, 0.4000),
        (1.60, 0.3650),
        (1.80, 0.3400),
        (2.00, 0.3200),
        (2.50, 0.2700),
        (3.00, 0.2300),
        (4.00, 0.1900),
        (5.00, 0.1700)
    ]

    // Standard G5 Mach vs Cd table
    private static let g5MachTable: [(mach: Double, cd: Double)] = [
        (0.00, 0.1300),
        (0.60, 0.1300),
        (0.70, 0.1310),
        (0.80, 0.1380),
        (0.90, 0.1600),
        (0.95, 0.2300),
        (1.00, 0.4000),
        (1.05, 0.4250),
        (1.10, 0.4200),
        (1.20, 0.4100),
        (1.40, 0.3750),
        (1.60, 0.3450),
        (1.80, 0.3200),
        (2.00, 0.3000),
        (2.50, 0.2600),
        (3.00, 0.2350),
        (4.00, 0.2000),
        (5.00, 0.1800)
    ]

    // Standard G6 Mach vs Cd table
    private static let g6MachTable: [(mach: Double, cd: Double)] = [
        (0.00, 0.1400),
        (0.60, 0.1400),
        (0.70, 0.1410),
        (0.80, 0.1500),
        (0.90, 0.1800),
        (0.95, 0.2500),
        (1.00, 0.4300),
        (1.05, 0.4550),
        (1.10, 0.4500),
        (1.20, 0.4350),
        (1.40, 0.3950),
        (1.60, 0.3650),
        (1.80, 0.3400),
        (2.00, 0.3200),
        (2.50, 0.2800),
        (3.00, 0.2500),
        (4.00, 0.2100),
        (5.00, 0.1900)
    ]

    // Standard G7 Mach vs Cd table
    private static let g7MachTable: [(mach: Double, cd: Double)] = [
        (0.00, 0.1197),
        (0.40, 0.1197),
        (0.60, 0.1198),
        (0.70, 0.1200),
        (0.80, 0.1245),
        (0.85, 0.1300),
        (0.90, 0.1450),
        (0.925, 0.1600),
        (0.95, 0.2050),
        (0.975, 0.2900),
        (1.00, 0.3800),
        (1.025, 0.4000),
        (1.05, 0.4040),
        (1.10, 0.4010),
        (1.15, 0.3950),
        (1.20, 0.3880),
        (1.30, 0.3700),
        (1.40, 0.3540),
        (1.50, 0.3400),
        (1.60, 0.3280),
        (1.80, 0.3060),
        (2.00, 0.2880),
        (2.20, 0.2720),
        (2.50, 0.2520),
        (3.00, 0.2280),
        (3.50, 0.2100),
        (4.00, 0.1960),
        (4.50, 0.1850),
        (5.00, 0.1760)
    ]

    // Standard G8 Mach vs Cd table
    private static let g8MachTable: [(mach: Double, cd: Double)] = [
        (0.00, 0.1300),
        (0.60, 0.1300),
        (0.70, 0.1310),
        (0.80, 0.1400),
        (0.90, 0.1700),
        (0.95, 0.2400),
        (1.00, 0.4100),
        (1.05, 0.4350),
        (1.10, 0.4300),
        (1.20, 0.4150),
        (1.40, 0.3750),
        (1.60, 0.3450),
        (1.80, 0.3200),
        (2.00, 0.3000),
        (2.50, 0.2600),
        (3.00, 0.2350),
        (4.00, 0.2000),
        (5.00, 0.1800)
    ]

    static func retard(
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        projectileVelocity: Double,
        speedOfSoundFPS: Double = defaultSpeedOfSoundFPS
    ) -> Double {
        guard projectileVelocity > 0, projectileVelocity < 10000, dragCoefficient > 0 else { return -1 }

        switch dragFunction {
        case .g1:
            return retardG1(dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity)
        case .g2:
            return retardTable(table: g2MachTable, dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity, speedOfSoundFPS: speedOfSoundFPS)
        case .g5:
            return retardTable(table: g5MachTable, dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity, speedOfSoundFPS: speedOfSoundFPS)
        case .g6:
            return retardTable(table: g6MachTable, dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity, speedOfSoundFPS: speedOfSoundFPS)
        case .g7:
            return retardTable(table: g7MachTable, dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity, speedOfSoundFPS: speedOfSoundFPS)
        case .g8:
            return retardTable(table: g8MachTable, dragCoefficient: dragCoefficient, projectileVelocity: projectileVelocity, speedOfSoundFPS: speedOfSoundFPS)
        }
    }

    private static func retardG1(dragCoefficient: Double, projectileVelocity: Double) -> Double {
        var acceleration: Double = -1
        var mass: Double = -1

        if projectileVelocity > 4230 { acceleration = 1.477404177730177e-04; mass = 1.9565 }
        else if projectileVelocity > 3680 { acceleration = 1.920339268755614e-04; mass = 1.925 }
        else if projectileVelocity > 3450 { acceleration = 2.894751026819746e-04; mass = 1.875 }
        else if projectileVelocity > 3295 { acceleration = 4.349905111115636e-04; mass = 1.825 }
        else if projectileVelocity > 3130 { acceleration = 6.520421871892662e-04; mass = 1.775 }
        else if projectileVelocity > 2960 { acceleration = 9.748073694078696e-04; mass = 1.725 }
        else if projectileVelocity > 2830 { acceleration = 1.453721560187286e-03; mass = 1.675 }
        else if projectileVelocity > 2680 { acceleration = 2.162887202930376e-03; mass = 1.625 }
        else if projectileVelocity > 2460 { acceleration = 3.209559783129881e-03; mass = 1.575 }
        else if projectileVelocity > 2225 { acceleration = 3.904368218691249e-03; mass = 1.55 }
        else if projectileVelocity > 2015 { acceleration = 3.222942271262336e-03; mass = 1.575 }
        else if projectileVelocity > 1890 { acceleration = 2.203329542297809e-03; mass = 1.625 }
        else if projectileVelocity > 1810 { acceleration = 1.511001028891904e-03; mass = 1.675 }
        else if projectileVelocity > 1730 { acceleration = 8.609957592468259e-04; mass = 1.75 }
        else if projectileVelocity > 1595 { acceleration = 4.086146797305117e-04; mass = 1.85 }
        else if projectileVelocity > 1520 { acceleration = 1.954473210037398e-04; mass = 1.95 }
        else if projectileVelocity > 1420 { acceleration = 5.431896266462351e-05; mass = 2.125 }
        else if projectileVelocity > 1360 { acceleration = 8.847742581674416e-06; mass = 2.375 }
        else if projectileVelocity > 1315 { acceleration = 1.456922328720298e-06; mass = 2.625 }
        else if projectileVelocity > 1280 { acceleration = 2.419485191895565e-07; mass = 2.875 }
        else if projectileVelocity > 1220 { acceleration = 1.657956321067612e-08; mass = 3.25 }
        else if projectileVelocity > 1185 { acceleration = 4.745469537157371e-10; mass = 3.75 }
        else if projectileVelocity > 1150 { acceleration = 1.379746590025088e-11; mass = 4.25 }
        else if projectileVelocity > 1100 { acceleration = 4.070157961147882e-13; mass = 4.75 }
        else if projectileVelocity > 1060 { acceleration = 2.938236954847331e-14; mass = 5.125 }
        else if projectileVelocity > 1025 { acceleration = 1.228597370774746e-14; mass = 5.25 }
        else if projectileVelocity > 980 { acceleration = 2.916938264100495e-14; mass = 5.125 }
        else if projectileVelocity > 945 { acceleration = 3.855099424807451e-13; mass = 4.75 }
        else if projectileVelocity > 905 { acceleration = 1.185097045689854e-11; mass = 4.25 }
        else if projectileVelocity > 860 { acceleration = 3.566129470974951e-10; mass = 3.75 }
        else if projectileVelocity > 810 { acceleration = 1.045513263966272e-08; mass = 3.25 }
        else if projectileVelocity > 780 { acceleration = 1.291159200846216e-07; mass = 2.875 }
        else if projectileVelocity > 750 { acceleration = 6.824429329105383e-07; mass = 2.625 }
        else if projectileVelocity > 700 { acceleration = 3.569169672385163e-06; mass = 2.375 }
        else if projectileVelocity > 640 { acceleration = 1.839015095899579e-05; mass = 2.125 }
        else if projectileVelocity > 600 { acceleration = 5.71117468873424e-05; mass = 1.95 }
        else if projectileVelocity > 550 { acceleration = 9.226557091973427e-05; mass = 1.875 }
        else if projectileVelocity > 250 { acceleration = 9.337991957131389e-05; mass = 1.875 }
        else if projectileVelocity > 100 { acceleration = 7.225247327590413e-05; mass = 1.925 }
        else if projectileVelocity > 65 { acceleration = 5.792684957074546e-05; mass = 1.975 }
        else if projectileVelocity > 0 { acceleration = 5.206214107320588e-05; mass = 2.000 }

        if acceleration != -1, mass != -1 {
            return acceleration * pow(projectileVelocity, mass) / dragCoefficient
        } else {
            return -1
        }
    }

    private static func retardTable(
        table: [(mach: Double, cd: Double)],
        dragCoefficient: Double,
        projectileVelocity: Double,
        speedOfSoundFPS: Double
    ) -> Double {
        let soundSpeed = max(100.0, speedOfSoundFPS)
        let mach = projectileVelocity / soundSpeed
        let cd = interpolateCd(table: table, mach: mach)
        return (standardDecelerationFactor * cd * projectileVelocity) / dragCoefficient
    }

    private static func interpolateCd(table: [(mach: Double, cd: Double)], mach: Double) -> Double {
        if mach <= table.first!.mach {
            return table.first!.cd
        }
        if mach >= table.last!.mach {
            return table.last!.cd
        }

        for i in 0..<(table.count - 1) {
            let p0 = table[i]
            let p1 = table[i + 1]
            if mach >= p0.mach && mach <= p1.mach {
                let factor = (mach - p0.mach) / (p1.mach - p0.mach)
                return p0.cd + factor * (p1.cd - p0.cd)
            }
        }

        return table.last!.cd
    }
}
