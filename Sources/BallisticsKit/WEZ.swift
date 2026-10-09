//
//  WEZ.swift
//  BallisticsKit
//
//  Created by Antigravity on 09/10/2026.
//

import Foundation

/// Target geometry models for Weapon Employment Zone (WEZ) and hit probability evaluation.
/// Based on Bryan Litz's *Applied Ballistics for Long Range Shooting* (Chapter 16: "Weapon Employment Zone Analysis").
public enum TargetGeometry: Sendable, Equatable {
    /// A circular target / steel gong of specified diameter.
    case circle(diameter: Measurement<UnitLength>)

    /// A rectangular target plate of specified width and height.
    case rectangle(width: Measurement<UnitLength>, height: Measurement<UnitLength>)

    /// A standardized IPSC silhouette target.
    case ipscSilhouette(zone: IPSCZone = .cZone)

    /// A military NATO silhouette target (e.g. NATO Type E).
    case natoSilhouette(type: NATOSilhouetteType = .typeE)

    public enum IPSCZone: Sendable, Equatable {
        case aZone
        case cZone
        case fullBody
    }

    public enum NATOSilhouetteType: Sendable, Equatable {
        case typeE // 0.5m x 1.0m (19.68" x 39.37")
        case headAndShoulders // 0.5m x 0.5m
    }

    /**
     Determines whether a shot impact offset (relative to target center) falls within the boundary of this target geometry.

     - Parameters:
       - horizontal: Horizontal impact offset from aim center (positive right, negative left).
       - vertical: Vertical impact offset from aim center (positive high, negative low).
     - Returns: `true` if the shot is a hit, `false` otherwise.
     */
    public func contains(
        horizontal: Measurement<UnitLength>,
        vertical: Measurement<UnitLength>
    ) -> Bool {
        let xInches = abs(horizontal.converted(to: .inches).value)
        let yInches = vertical.converted(to: .inches).value // signed for asymmetric humanoids

        switch self {
        case .circle(let diameter):
            let radiusInches = diameter.converted(to: .inches).value / 2.0
            return (xInches * xInches + yInches * yInches) <= (radiusInches * radiusInches)

        case .rectangle(let width, let height):
            let halfW = width.converted(to: .inches).value / 2.0
            let halfH = height.converted(to: .inches).value / 2.0
            return xInches <= halfW && abs(yInches) <= halfH

        case .ipscSilhouette(let zone):
            // IPSC Target centered at center of A-zone body
            // Width: 45 cm (17.72"), Total Height: 75 cm (29.53")
            switch zone {
            case .aZone:
                // Body A-zone: 15 cm (5.91") wide x 28 cm (11.02") tall [-5.51", +5.51"]
                let inBodyA = xInches <= (5.91 / 2.0) && abs(yInches) <= 5.51
                // Head A-zone: 5 cm (1.97") square at top [y between 8.5" and 12.5"]
                let inHeadA = xInches <= (1.97 / 2.0) && (yInches >= 8.5 && yInches <= 12.5)
                return inBodyA || inHeadA

            case .cZone:
                // C-zone: 30 cm (11.81") wide x 45 cm (17.72") tall
                let inBodyC = xInches <= (11.81 / 2.0) && abs(yInches) <= 8.86
                // Head: 15 cm (5.91") wide at top [y between 7.5" and 13.5"]
                let inHeadC = xInches <= (5.91 / 2.0) && (yInches >= 7.5 && yInches <= 13.5)
                return inBodyC || inHeadC

            case .fullBody:
                // Full silhouette with shoulder cutoffs
                let inHead = xInches <= (5.91 / 2.0) && (yInches >= 7.5 && yInches <= 14.76)
                let inTorso = xInches <= (17.72 / 2.0) && abs(yInches) <= 7.5
                let inLower = xInches <= (17.72 / 2.0) && (yInches <= 0 && yInches >= -14.76)
                return inHead || inTorso || inLower
            }

        case .natoSilhouette(let type):
            switch type {
            case .typeE:
                // NATO Type E silhouette: 0.50m (19.68") wide by 1.0m (39.37") tall
                let halfW = 19.68 / 2.0
                let halfH = 39.37 / 2.0
                return xInches <= halfW && abs(yInches) <= halfH

            case .headAndShoulders:
                let halfW = 19.68 / 2.0
                let halfH = 19.68 / 2.0
                return xInches <= halfW && abs(yInches) <= halfH
            }
        }
    }
}

// MARK: - MonteCarloResult WEZ Hit Probability Extension

extension MonteCarloResult {

    /**
     Computes the number of shots that hit the target geometry.

     - Parameters:
       - target: The target shape and dimensions.
       - aimOffsetHorizontal: Optional aiming bias horizontal offset.
       - aimOffsetVertical: Optional aiming bias vertical offset.
     - Returns: Number of confirmed hits.
     */
    public func hitCount(
        for target: TargetGeometry,
        aimOffsetHorizontal: Measurement<UnitLength> = Measurement(value: 0, unit: .inches),
        aimOffsetVertical: Measurement<UnitLength> = Measurement(value: 0, unit: .inches)
    ) -> Int {
        var count = 0
        for shot in shots {
            let effX = shot.horizontalDeviation + aimOffsetHorizontal
            let effY = shot.verticalDeviation + aimOffsetVertical
            if target.contains(horizontal: effX, vertical: effY) {
                count += 1
            }
        }
        return count
    }

    /**
     Computes the hit probability percentage (0.0% to 100.0%) for a given target geometry.

     - Parameters:
       - target: The target shape and dimensions.
       - aimOffsetHorizontal: Optional aiming bias horizontal offset.
       - aimOffsetVertical: Optional aiming bias vertical offset.
     - Returns: Hit probability as a percentage (e.g. 87.5).
     */
    public func hitProbability(
        for target: TargetGeometry,
        aimOffsetHorizontal: Measurement<UnitLength> = Measurement(value: 0, unit: .inches),
        aimOffsetVertical: Measurement<UnitLength> = Measurement(value: 0, unit: .inches)
    ) -> Double {
        guard !shots.isEmpty else { return 0.0 }
        let hits = hitCount(
            for: target,
            aimOffsetHorizontal: aimOffsetHorizontal,
            aimOffsetVertical: aimOffsetVertical
        )
        return (Double(hits) / Double(shots.count)) * 100.0
    }
}

// MARK: - WEZ Sensitivity & Uncertainty Budget Analysis

/// Result of a Weapon Employment Zone (WEZ) uncertainty sensitivity analysis.
public struct WEZAnalysisResult: Sendable, Equatable {
    /// Baseline hit probability percentage (0% to 100%).
    public let baselineHitProbability: Double

    /// Target geometry evaluated.
    public let target: TargetGeometry

    /// Target distance.
    public let targetDistance: Measurement<UnitLength>

    /// Hit probability percentage if range uncertainty alone is introduced or altered.
    public let rangeImpactProbability: Double

    /// Hit probability percentage if wind uncertainty alone is introduced or altered.
    public let windImpactProbability: Double

    /// Hit probability percentage if muzzle velocity SD alone is altered.
    public let velocityImpactProbability: Double

    /// Primary limiting uncertainty factor ("Range", "Wind", "Muzzle Velocity", or "Precision").
    public let primaryLimitingFactor: String
}

public struct WEZAnalysis: Sendable {

    /**
     Runs a complete Weapon Employment Zone (WEZ) analysis following Bryan Litz's methodology.
     Evaluates how uncertainties in laser rangefinding, wind estimation, ammo consistency, and shooter precision
     collectively and individually impact the probability of a hit on target.
     */
    public static func analyze(
        shotCount: Int = 150,
        targetDistance: Measurement<UnitLength>,
        target: TargetGeometry,
        nominalDispersion: MonteCarloDispersion = MonteCarloDispersion(),
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double,
        nominalVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        nominalWindSpeed: Measurement<UnitSpeed> = Measurement(value: 5, unit: .milesPerHour),
        weight: Measurement<UnitMass> = Measurement(value: 175, unit: .grains),
        atmosphere: Atmosphere? = nil,
        randomSeed: UInt64 = 42
    ) -> WEZAnalysisResult {
        // 1. Baseline simulation
        let baseline = MonteCarlo.simulate(
            shotCount: shotCount,
            targetDistance: targetDistance,
            dispersion: nominalDispersion,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            nominalVelocity: nominalVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            nominalWindSpeed: nominalWindSpeed,
            weight: weight,
            atmosphere: atmosphere,
            randomSeed: randomSeed
        )
        let baselineHitProb = baseline.hitProbability(for: target)

        // 2. Wind sensitivity (double wind SD)
        var windDegradedDisp = nominalDispersion
        windDegradedDisp.windSpeedSD = windDegradedDisp.windSpeedSD * 2.0
        let windSim = MonteCarlo.simulate(
            shotCount: shotCount,
            targetDistance: targetDistance,
            dispersion: windDegradedDisp,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            nominalVelocity: nominalVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            nominalWindSpeed: nominalWindSpeed,
            weight: weight,
            atmosphere: atmosphere,
            randomSeed: randomSeed
        )
        let windProb = windSim.hitProbability(for: target)

        // 3. Velocity sensitivity (double V0 SD)
        var v0DegradedDisp = nominalDispersion
        v0DegradedDisp.muzzleVelocitySD = v0DegradedDisp.muzzleVelocitySD * 2.0
        let v0Sim = MonteCarlo.simulate(
            shotCount: shotCount,
            targetDistance: targetDistance,
            dispersion: v0DegradedDisp,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            nominalVelocity: nominalVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            nominalWindSpeed: nominalWindSpeed,
            weight: weight,
            atmosphere: atmosphere,
            randomSeed: randomSeed
        )
        let v0Prob = v0Sim.hitProbability(for: target)

        // 4. Range sensitivity (evaluating slight distance offset error e.g. +2.5%)
        let rangeOffset = targetDistance * 1.025
        let rangeSim = MonteCarlo.simulate(
            shotCount: shotCount,
            targetDistance: rangeOffset,
            dispersion: nominalDispersion,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            nominalVelocity: nominalVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            nominalWindSpeed: nominalWindSpeed,
            weight: weight,
            atmosphere: atmosphere,
            randomSeed: randomSeed
        )
        let rangeProb = rangeSim.hitProbability(for: target)

        // Determine dominant loss
        let windLoss = baselineHitProb - windProb
        let v0Loss = baselineHitProb - v0Prob
        let rangeLoss = baselineHitProb - rangeProb

        let primaryFactor: String
        if windLoss >= v0Loss && windLoss >= rangeLoss {
            primaryFactor = "Wind Estimation"
        } else if rangeLoss >= windLoss && rangeLoss >= v0Loss {
            primaryFactor = "Rangefinding Uncertainty"
        } else {
            primaryFactor = "Muzzle Velocity Consistency"
        }

        return WEZAnalysisResult(
            baselineHitProbability: baselineHitProb,
            target: target,
            targetDistance: targetDistance,
            rangeImpactProbability: rangeProb,
            windImpactProbability: windProb,
            velocityImpactProbability: v0Prob,
            primaryLimitingFactor: primaryFactor
        )
    }
}
