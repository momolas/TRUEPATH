//
//  MonteCarlo.swift
//  BallisticsKit
//
//  Created by Antigravity on 20/09/2026.
//

import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Configuration for stochastic dispersion in Monte Carlo ballistics simulations.
public struct MonteCarloDispersion: Sendable, Equatable {
    /// Standard deviation of muzzle velocity (e.g. 10 to 20 ft/s for match ammo).
    public var muzzleVelocitySD: Measurement<UnitSpeed>

    /// Standard deviation of crosswind speed (e.g. 1 to 3 mph for turbulent conditions).
    public var windSpeedSD: Measurement<UnitSpeed>

    /// Mechanical / shooter angular precision standard deviation (e.g. 0.25 to 0.5 MOA).
    public var shooterAngularSD: Measurement<UnitAngle>

    public init(
        muzzleVelocitySD: Measurement<UnitSpeed> = Measurement(value: 12, unit: .feetPerSecond),
        windSpeedSD: Measurement<UnitSpeed> = Measurement(value: 2, unit: .milesPerHour),
        shooterAngularSD: Measurement<UnitAngle> = Measurement(value: 0.3, unit: .minutesOfAngle)
    ) {
        self.muzzleVelocitySD = muzzleVelocitySD
        self.windSpeedSD = windSpeedSD
        self.shooterAngularSD = shooterAngularSD
    }
}

/// A single shot result in a Monte Carlo batch simulation.
public struct MonteCarloShot: Sendable, Equatable {
    /// Horizontal impact deviation from aim point (positive = right, negative = left).
    public var horizontalDeviation: Measurement<UnitLength>

    /// Vertical impact deviation from aim point (positive = high, negative = low).
    public var verticalDeviation: Measurement<UnitLength>

    /// Radial distance from aim point to impact.
    public var radialDistance: Measurement<UnitLength>

    /// Terminal velocity at the target distance.
    public var terminalVelocity: Measurement<UnitSpeed>

    /// Terminal kinetic energy at the target distance.
    public var terminalEnergy: Measurement<UnitEnergy>

    /// Flight time to target.
    public var timeOfFlight: Measurement<UnitDuration>

    public init(
        horizontalDeviation: Measurement<UnitLength>,
        verticalDeviation: Measurement<UnitLength>,
        radialDistance: Measurement<UnitLength>,
        terminalVelocity: Measurement<UnitSpeed>,
        terminalEnergy: Measurement<UnitEnergy>,
        timeOfFlight: Measurement<UnitDuration>
    ) {
        self.horizontalDeviation = horizontalDeviation
        self.verticalDeviation = verticalDeviation
        self.radialDistance = radialDistance
        self.terminalVelocity = terminalVelocity
        self.terminalEnergy = terminalEnergy
        self.timeOfFlight = timeOfFlight
    }
}

/// Aggregated statistical summary of a Monte Carlo shot series, computed via Apple Accelerate (vDSP).
public struct MonteCarloResult: Sendable, Equatable {
    /// Total number of shots simulated.
    public var sampleCount: Int

    /// Target distance at which dispersion is evaluated.
    public var targetDistance: Measurement<UnitLength>

    /// Mean Point of Impact (MPI) horizontal offset.
    public var meanHorizontalDeviation: Measurement<UnitLength>

    /// Mean Point of Impact (MPI) vertical offset.
    public var meanVerticalDeviation: Measurement<UnitLength>

    /// Horizontal standard deviation (1-sigma).
    public var horizontalSD: Measurement<UnitLength>

    /// Vertical standard deviation (1-sigma).
    public var verticalSD: Measurement<UnitLength>

    /// Extreme Spread (ES) horizontal (maximum minus minimum horizontal impact).
    public var extremeSpreadHorizontal: Measurement<UnitLength>

    /// Extreme Spread (ES) vertical (maximum minus minimum vertical impact).
    public var extremeSpreadVertical: Measurement<UnitLength>

    /// Circular Error Probable (CEP 50%): Radius enclosing 50% of impacts.
    public var cep50: Measurement<UnitLength>

    /// 95% Confidence Radius (R95): Radius enclosing 95% of impacts.
    public var r95: Measurement<UnitLength>

    /// Mean terminal velocity across all shots.
    public var meanTerminalVelocity: Measurement<UnitSpeed>

    /// Velocity standard deviation at target.
    public var terminalVelocitySD: Measurement<UnitSpeed>

    /// Mean terminal kinetic energy across all shots.
    public var meanTerminalEnergy: Measurement<UnitEnergy>

    /// Detailed individual shot data.
    public var shots: [MonteCarloShot]

    public init(
        sampleCount: Int,
        targetDistance: Measurement<UnitLength>,
        meanHorizontalDeviation: Measurement<UnitLength>,
        meanVerticalDeviation: Measurement<UnitLength>,
        horizontalSD: Measurement<UnitLength>,
        verticalSD: Measurement<UnitLength>,
        extremeSpreadHorizontal: Measurement<UnitLength>,
        extremeSpreadVertical: Measurement<UnitLength>,
        cep50: Measurement<UnitLength>,
        r95: Measurement<UnitLength>,
        meanTerminalVelocity: Measurement<UnitSpeed>,
        terminalVelocitySD: Measurement<UnitSpeed>,
        meanTerminalEnergy: Measurement<UnitEnergy>,
        shots: [MonteCarloShot]
    ) {
        self.sampleCount = sampleCount
        self.targetDistance = targetDistance
        self.meanHorizontalDeviation = meanHorizontalDeviation
        self.meanVerticalDeviation = meanVerticalDeviation
        self.horizontalSD = horizontalSD
        self.verticalSD = verticalSD
        self.extremeSpreadHorizontal = extremeSpreadHorizontal
        self.extremeSpreadVertical = extremeSpreadVertical
        self.cep50 = cep50
        self.r95 = r95
        self.meanTerminalVelocity = meanTerminalVelocity
        self.terminalVelocitySD = terminalVelocitySD
        self.meanTerminalEnergy = meanTerminalEnergy
        self.shots = shots
    }
}

/// High-performance Monte Carlo ballistic dispersion solver.
/// Leverages Apple Accelerate (vDSP & vForce) for hardware-accelerated statistical reductions and batch evaluations.
public struct MonteCarlo: Sendable {

    /**
     Simulates a stochastic series of shots and computes dispersion statistics using Apple Accelerate.

     - Parameters:
       - shotCount: Number of rounds to simulate (e.g. 100 to 1000).
       - targetDistance: The distance at which impacts and dispersion are measured.
       - dispersion: Stochastic variation parameters (V0 SD, wind SD, angular SD).
       - dragFunction: Standard drag function.
       - dragCoefficient: Nominal projectile ballistic coefficient.
       - nominalVelocity: Nominal muzzle velocity.
       - sightHeight: Sight height over bore.
       - zeroRange: Firearm zero range.
       - nominalWindSpeed: Nominal ambient wind speed.
       - nominalWindAngle: Nominal wind angle in degrees (90° = crosswind).
       - weight: Projectile mass.
       - atmosphere: Environmental conditions.
       - randomSeed: Optional seed for deterministic testing.

     - Returns:
       A `MonteCarloResult` containing individual shots and accelerated statistical metrics.
     */
    public static func simulate(
        shotCount: Int = 100,
        targetDistance: Measurement<UnitLength>,
        dispersion: MonteCarloDispersion = MonteCarloDispersion(),
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        nominalVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        nominalWindSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        nominalWindAngle: Double = 90,
        weight: Measurement<UnitMass> = Measurement(value: 175, unit: .grains),
        atmosphere: Atmosphere? = nil,
        randomSeed: UInt64? = nil
    ) -> MonteCarloResult {
        precondition(shotCount >= 2, "Monte Carlo simulation requires at least 2 shots.")

        let nominalV0 = nominalVelocity.converted(to: .feetPerSecond).value
        let sdV0 = dispersion.muzzleVelocitySD.converted(to: .feetPerSecond).value

        let nominalWind = nominalWindSpeed.converted(to: .milesPerHour).value
        let sdWind = dispersion.windSpeedSD.converted(to: .milesPerHour).value

        let sdAngleRad = dispersion.shooterAngularSD.converted(to: .radians).value
        let targetDistanceInches = targetDistance.converted(to: .inches).value

        // Baseline trajectory for zero reference
        let baseline = Ballistics.solve3DOF(
            preferredDistanceUnit: .yards,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: nominalVelocity,
            sightHeight: sightHeight,
            shootingAngle: Measurement(value: 0, unit: .degrees),
            zeroRange: zeroRange,
            atmosphere: atmosphere,
            windSpeed: nominalWindSpeed,
            windAngle: nominalWindAngle,
            weight: weight,
            distanceStep: targetDistance,
            maxRange: targetDistance + Measurement(value: 10, unit: .yards)
        )

        let baselinePoint = baseline.getPoint(at: targetDistance)
        let baselineDropInches = baselinePoint?.drop.converted(to: .inches).value ?? 0
        let baselineWindageInches = baselinePoint?.windage.converted(to: .inches).value ?? 0

        // Deterministic or pseudo-random generator
        var rng = CustomRNG(seed: randomSeed ?? 0x123456789ABCDEF0)

        var xDeviations = [Double]()
        var yDeviations = [Double]()
        var radialDistances = [Double]()
        var velocities = [Double]()
        var energies = [Double]()
        var times = [Double]()
        var shots = [MonteCarloShot]()

        xDeviations.reserveCapacity(shotCount)
        yDeviations.reserveCapacity(shotCount)
        radialDistances.reserveCapacity(shotCount)
        velocities.reserveCapacity(shotCount)
        energies.reserveCapacity(shotCount)
        times.reserveCapacity(shotCount)
        shots.reserveCapacity(shotCount)

        for _ in 0..<shotCount {
            // Sample stochastic deviations via Box-Muller Gaussian transform
            let (g1, g2) = rng.nextGaussianPair()
            let (g3, g4) = rng.nextGaussianPair()

            let shotV0 = max(200.0, nominalV0 + g1 * sdV0)
            let shotWind = nominalWind + g2 * sdWind
            let shotAngularY = g3 * sdAngleRad
            let shotAngularX = g4 * sdAngleRad

            let shotSolution = Ballistics.solve3DOF(
                preferredDistanceUnit: .yards,
                dragFunction: dragFunction,
                dragCoefficient: dragCoefficient,
                initialVelocity: Measurement(value: shotV0, unit: .feetPerSecond),
                sightHeight: sightHeight,
                shootingAngle: Measurement(value: 0, unit: .degrees),
                zeroRange: zeroRange,
                atmosphere: atmosphere,
                windSpeed: Measurement(value: abs(shotWind), unit: .milesPerHour),
                windAngle: shotWind >= 0 ? nominalWindAngle : (nominalWindAngle + 180),
                weight: weight,
                distanceStep: targetDistance,
                maxRange: targetDistance + Measurement(value: 10, unit: .yards)
            )

            if let p = shotSolution.getPoint(at: targetDistance) {
                let yPhysical = p.drop.converted(to: .inches).value
                let xPhysical = p.windage.converted(to: .inches).value

                // Combine ballistic trajectory delta with barrel/shooter angular dispersion
                let yTotalDev = (yPhysical - baselineDropInches) + (shotAngularY * targetDistanceInches)
                let xTotalDev = (xPhysical - baselineWindageInches) + (shotAngularX * targetDistanceInches)
                let rDist = sqrt(xTotalDev * xTotalDev + yTotalDev * yTotalDev)

                let vEnd = p.velocity.converted(to: .feetPerSecond).value
                let eEnd = p.energy.converted(to: .footPounds).value
                let tEnd = p.travelTime.converted(to: .seconds).value

                xDeviations.append(xTotalDev)
                yDeviations.append(yTotalDev)
                radialDistances.append(rDist)
                velocities.append(vEnd)
                energies.append(eEnd)
                times.append(tEnd)

                shots.append(
                    MonteCarloShot(
                        horizontalDeviation: Measurement(value: xTotalDev, unit: .inches),
                        verticalDeviation: Measurement(value: yTotalDev, unit: .inches),
                        radialDistance: Measurement(value: rDist, unit: .inches),
                        terminalVelocity: Measurement(value: vEnd, unit: .feetPerSecond),
                        terminalEnergy: Measurement(value: eEnd, unit: .footPounds),
                        timeOfFlight: Measurement(value: tEnd, unit: .seconds)
                    )
                )
            }
        }

        // Compute accelerated statistics using Apple Accelerate vDSP
        let meanX: Double
        let sdX: Double
        let minX: Double
        let maxX: Double

        let meanY: Double
        let sdY: Double
        let minY: Double
        let maxY: Double

        let meanV: Double
        let sdV: Double
        let meanE: Double

        #if canImport(Accelerate)
        meanX = vDSP.mean(xDeviations)
        sdX = vDSP.standardDeviation(xDeviations)
        minX = vDSP.minimum(xDeviations)
        maxX = vDSP.maximum(xDeviations)

        meanY = vDSP.mean(yDeviations)
        sdY = vDSP.standardDeviation(yDeviations)
        minY = vDSP.minimum(yDeviations)
        maxY = vDSP.maximum(yDeviations)

        meanV = vDSP.mean(velocities)
        sdV = vDSP.standardDeviation(velocities)
        meanE = vDSP.mean(energies)
        #else
        meanX = xDeviations.reduce(0.0, +) / Double(xDeviations.count)
        sdX = sqrt(xDeviations.map { pow($0 - meanX, 2) }.reduce(0.0, +) / Double(max(1, xDeviations.count - 1)))
        minX = xDeviations.min() ?? 0
        maxX = xDeviations.max() ?? 0

        meanY = yDeviations.reduce(0.0, +) / Double(yDeviations.count)
        sdY = sqrt(yDeviations.map { pow($0 - meanY, 2) }.reduce(0.0, +) / Double(max(1, yDeviations.count - 1)))
        minY = yDeviations.min() ?? 0
        maxY = yDeviations.max() ?? 0

        meanV = velocities.reduce(0.0, +) / Double(velocities.count)
        sdV = sqrt(velocities.map { pow($0 - meanV, 2) }.reduce(0.0, +) / Double(max(1, velocities.count - 1)))
        meanE = energies.reduce(0.0, +) / Double(energies.count)
        #endif

        // Radial percentiles for CEP (50%) and R95 (95%)
        let sortedRadials = radialDistances.sorted()
        let cepIndex = min(sortedRadials.count - 1, Int(Double(sortedRadials.count) * 0.50))
        let r95Index = min(sortedRadials.count - 1, Int(Double(sortedRadials.count) * 0.95))

        let cep50Val = sortedRadials.isEmpty ? 0 : sortedRadials[cepIndex]
        let r95Val = sortedRadials.isEmpty ? 0 : sortedRadials[r95Index]

        return MonteCarloResult(
            sampleCount: shots.count,
            targetDistance: targetDistance,
            meanHorizontalDeviation: Measurement(value: meanX, unit: .inches),
            meanVerticalDeviation: Measurement(value: meanY, unit: .inches),
            horizontalSD: Measurement(value: sdX, unit: .inches),
            verticalSD: Measurement(value: sdY, unit: .inches),
            extremeSpreadHorizontal: Measurement(value: max(0, maxX - minX), unit: .inches),
            extremeSpreadVertical: Measurement(value: max(0, maxY - minY), unit: .inches),
            cep50: Measurement(value: cep50Val, unit: .inches),
            r95: Measurement(value: r95Val, unit: .inches),
            meanTerminalVelocity: Measurement(value: meanV, unit: .feetPerSecond),
            terminalVelocitySD: Measurement(value: sdV, unit: .feetPerSecond),
            meanTerminalEnergy: Measurement(value: meanE, unit: .footPounds),
            shots: shots
        )
    }
}

// MARK: - Pseudo-Random Gaussian Generator
private struct CustomRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed != 0 ? seed : 0xDEADBEEFCAFEBABE
    }

    mutating func nextDouble() -> Double {
        // Xorshift64star
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let val = state &* 0x2545F4914F6CDD1D
        return Double(val >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func nextGaussianPair() -> (Double, Double) {
        // Box-Muller transform
        let u1 = max(1e-15, nextDouble())
        let u2 = nextDouble()
        let r = sqrt(-2.0 * log(u1))
        let theta = 2.0 * Double.pi * u2
        return (r * cos(theta), r * sin(theta))
    }
}
