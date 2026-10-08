//
//  Ballistics.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Represents a computed ballistic trajectory solution with continuous query and interpolation capability.
public struct Ballistics: Sendable, Equatable, Hashable {

    /// Stores sampled points along the trajectory at fixed distance steps in the preferred unit.
    public internal(set) var distances: [Point] = []

    /// The preferred distance unit used for trajectory sampling.
    public let preferredDistanceUnit: UnitLength

    /// The sampling step distance in preferred units.
    public let distanceStep: Measurement<UnitLength>

    public init(
        preferredDistanceUnit: UnitLength = .yards,
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards)
    ) {
        self.preferredDistanceUnit = preferredDistanceUnit
        self.distanceStep = distanceStep.converted(to: preferredDistanceUnit)
    }

    /**
     Solves the projectile trajectory using the 3-DOF point-mass solver.

     - Parameters:
       - preferredDistanceUnit: The preferred distance unit, used for sampling (e.g., .yards or .meters). Default is .yards.
       - dragFunction: The aerodynamic drag function (.g1, .g2, .g5, .g6, .g7, .g8). Default is .g1.
       - dragCoefficient: The drag coefficient of the projectile.
       - initialVelocity: The muzzle velocity of the projectile.
       - sightHeight: The height of the sight above the bore axis.
       - shootingAngle: The actual angle of elevation at which the projectile is fired. Positive is up, negative is down.
       - zeroRange: The distance the projectile is zeroed at.
       - atmosphere: The atmospheric conditions to consider (temperature, pressure, altitude, humidity). Optional.
       - windSpeed: The speed of the wind.
       - windAngle: The direction of the wind relative to the projectile's path, in degrees (0° = headwind, 90° = left to right).
       - weight: The projectile weight.
       - distanceStep: The sampling step in the preferred unit. Default is 1 yard.
       - twist: Barrel rifling twist rate (e.g. 1 turn in 10 inches). Optional.
       - twistDirection: Barrel rifling twist direction (.right or .left). Default is .right.
       - bulletDiameter: Projectile caliber/diameter. Optional, used for Miller stability factor.
       - bulletLength: Projectile length. Optional, used for Miller stability factor.
       - latitude: Firing position latitude. Optional, used for Coriolis deflections.
       - azimuth: Shooting compass azimuth. Optional, used for Coriolis deflections.

     - Returns:
       A ballistics object containing trajectory points sampled at regular distance steps with continuous query capability.
    */
    /**
     Solves the projectile trajectory using the unified NATO STANAG 4355 Modified Point Mass (4-DOF) solver.

     - Parameters:
       - preferredDistanceUnit: The preferred distance unit, used for sampling (e.g., .yards or .meters). Default is .yards.
       - dragFunction: The aerodynamic drag function (.g1, .g2, .g5, .g6, .g7, .g8). Default is .g1.
       - dragCoefficient: The drag coefficient of the projectile.
       - initialVelocity: The muzzle velocity of the projectile.
       - sightHeight: The height of the sight above the bore axis.
       - shootingAngle: The actual angle of elevation at which the projectile is fired. Positive is up, negative is down.
       - zeroRange: The distance the projectile is zeroed at.
       - atmosphere: The atmospheric conditions to consider (temperature, pressure, altitude, humidity). Optional.
       - windSpeed: The speed of the wind.
       - windAngle: The direction of the wind relative to the projectile's path, in degrees (0° = headwind, 90° = left to right).
       - weight: The projectile weight.
       - distanceStep: The sampling step in the preferred unit. Default is 1 yard.
       - twist: Barrel rifling twist rate (e.g. 1 turn in 10 inches). Optional.
       - twistDirection: Barrel rifling twist direction (.right or .left). Default is .right.
       - bulletDiameter: Projectile caliber/diameter. Optional.
       - bulletLength: Projectile length. Optional.
       - latitude: Firing position latitude. Optional.
       - azimuth: Shooting compass azimuth. Optional.
       - tolerance: Numerical tolerance configuration for adaptive Runge-Kutta Dormand-Prince integration. Default is .standard.
       - maxRange: Maximum downrange distance limit. Optional.

     - Returns:
       A ballistics object containing trajectory points sampled at regular distance steps with continuous query capability.
    */
    public static func solve4DOF(
        preferredDistanceUnit: UnitLength = .yards,
        dragFunction: DragFunction = .g1,
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
        return Solver4DOF.solve(
            preferredDistanceUnit: preferredDistanceUnit,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            shootingAngle: shootingAngle,
            zeroRange: zeroRange,
            atmosphere: atmosphere,
            windSpeed: windSpeed,
            windAngle: windAngle,
            weight: weight,
            distanceStep: distanceStep,
            twist: twist,
            twistDirection: twistDirection,
            bulletDiameter: bulletDiameter,
            bulletLength: bulletLength,
            latitude: latitude,
            azimuth: azimuth,
            tolerance: tolerance,
            maxRange: maxRange
        )
    }


    /// Primary entrypoint solving the projectile trajectory using NATO STANAG 4355 4-DOF.
    @inlinable
    public static func solve(
        preferredDistanceUnit: UnitLength = .yards,
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        zeroRange: Measurement<UnitLength>,
        atmosphere: Atmosphere? = nil,
        windSpeed: Measurement<UnitSpeed> = Measurement(value: 0, unit: .milesPerHour),
        windAngle: Double = 0,
        weight: Measurement<UnitMass> = Measurement<UnitMass>(value: 0, unit: .grains),
        distanceStep: Measurement<UnitLength> = Measurement(value: 1, unit: .yards),
        twist: Measurement<UnitLength>? = nil,
        twistDirection: TwistDirection = .right,
        bulletDiameter: Measurement<UnitLength>? = nil,
        bulletLength: Measurement<UnitLength>? = nil,
        latitude: Measurement<UnitAngle>? = nil,
        azimuth: Measurement<UnitAngle>? = nil,
        maxRange: Measurement<UnitLength>? = nil
    ) -> Ballistics {
        solve4DOF(
            preferredDistanceUnit: preferredDistanceUnit,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            shootingAngle: shootingAngle,
            zeroRange: zeroRange,
            atmosphere: atmosphere,
            windSpeed: windSpeed,
            windAngle: windAngle,
            weight: weight,
            distanceStep: distanceStep,
            twist: twist,
            twistDirection: twistDirection,
            bulletDiameter: bulletDiameter,
            bulletLength: bulletLength,
            latitude: latitude,
            azimuth: azimuth,
            maxRange: maxRange
        )
    }

    /**
     Retrieves the ballistic point at the specified target distance.
     Performs smooth continuous linear interpolation if the requested distance falls between two sampled distance steps.

     - Parameter distance: The distance at which to retrieve or interpolate the ballistic metrics.
     - Returns: The interpolated `Point`, or `nil` if out of bounds.
     */
    public func getPoint(at distance: Measurement<UnitLength>) -> Point? {
        guard !distances.isEmpty else { return nil }

        let requestedInPreferred = distance.converted(to: preferredDistanceUnit).value
        let stepValue = distanceStep.value
        guard stepValue > 0 else { return nil }

        let exactIndex = requestedInPreferred / stepValue
        guard exactIndex >= 0 else { return nil }

        let lowerIndex = Int(floor(exactIndex))
        let upperIndex = Int(ceil(exactIndex))

        guard lowerIndex < distances.count else { return nil }

        if lowerIndex == upperIndex || upperIndex >= distances.count {
            return distances[lowerIndex]
        }

        let p0 = distances[lowerIndex]
        let p1 = distances[upperIndex]
        let factor = exactIndex - Double(lowerIndex)

        let interpDrop = p0.drop.value + factor * (p1.drop.value - p0.drop.value)
        let interpDropCorr = p0.dropCorrection.value + factor * (p1.dropCorrection.value - p0.dropCorrection.value)
        let interpWindage = p0.windage.value + factor * (p1.windage.value - p0.windage.value)
        let interpWindageCorr = p0.windageCorrection.value + factor * (p1.windageCorrection.value - p0.windageCorrection.value)
        let interpTime = p0.travelTime.value + factor * (p1.travelTime.value - p0.travelTime.value)
        let interpV = p0.velocity.value + factor * (p1.velocity.value - p0.velocity.value)
        let interpVx = p0.velocityX.value + factor * (p1.velocityX.value - p0.velocityX.value)
        let interpVy = p0.velocityY.value + factor * (p1.velocityY.value - p0.velocityY.value)
        let interpEnergy = p0.energy.value + factor * (p1.energy.value - p0.energy.value)

        let interpSpinDrift: Measurement<UnitLength>? = {
            guard let s0 = p0.spinDrift, let s1 = p1.spinDrift else { return nil }
            let s1Val = s1.converted(to: s0.unit).value
            return Measurement(value: s0.value + factor * (s1Val - s0.value), unit: s0.unit)
        }()

        let interpCoriolisHoriz: Measurement<UnitLength>? = {
            guard let c0 = p0.coriolisHorizontal, let c1 = p1.coriolisHorizontal else { return nil }
            let c1Val = c1.converted(to: c0.unit).value
            return Measurement(value: c0.value + factor * (c1Val - c0.value), unit: c0.unit)
        }()

        let interpCoriolisVert: Measurement<UnitLength>? = {
            guard let c0 = p0.coriolisVertical, let c1 = p1.coriolisVertical else { return nil }
            let c1Val = c1.converted(to: c0.unit).value
            return Measurement(value: c0.value + factor * (c1Val - c0.value), unit: c0.unit)
        }()

        return Point(
            range: distance,
            drop: Measurement(value: interpDrop, unit: p0.drop.unit),
            dropCorrection: Measurement(value: interpDropCorr, unit: p0.dropCorrection.unit),
            windage: Measurement(value: interpWindage, unit: p0.windage.unit),
            windageCorrection: Measurement(value: interpWindageCorr, unit: p0.windageCorrection.unit),
            travelTime: Measurement(value: interpTime, unit: p0.travelTime.unit),
            velocity: Measurement(value: interpV, unit: p0.velocity.unit),
            velocityX: Measurement(value: interpVx, unit: p0.velocityX.unit),
            velocityY: Measurement(value: interpVy, unit: p0.velocityY.unit),
            energy: Measurement(value: interpEnergy, unit: p0.energy.unit),
            spinDrift: interpSpinDrift,
            coriolisHorizontal: interpCoriolisHoriz,
            coriolisVertical: interpCoriolisVert
        )
    }

    /**
     Vectorized batch retrieval of ballistic points using Apple Accelerate.
     Interpolates drops, windages, velocities, energies, etc. for an entire array of target distances simultaneously.

     - Parameter distancesArray: The array of distances at which to retrieve or interpolate points.
     - Returns: An array of interpolated `Point` objects for all valid in-bounds distances.
     */
    public func getPoints(at distancesArray: [Measurement<UnitLength>]) -> [Point] {
        guard !distances.isEmpty, !distancesArray.isEmpty else { return [] }

        let stepVal = distanceStep.value
        guard stepVal > 0 else { return [] }

        let maxIdx = Double(distances.count - 1)
        var validQueries = [(queryIndex: Double, originalDistance: Measurement<UnitLength>)]()
        validQueries.reserveCapacity(distancesArray.count)

        for d in distancesArray {
            let req = d.converted(to: preferredDistanceUnit).value
            let qIdx = req / stepVal
            if qIdx >= 0 && qIdx <= maxIdx {
                validQueries.append((queryIndex: qIdx, originalDistance: d))
            }
        }

        guard !validQueries.isEmpty else { return [] }

        let count = validQueries.count
        let indices = validQueries.map { $0.queryIndex }

        let nDist = distances.count
        var dropsTable = [Double](repeating: 0, count: nDist)
        var dropCorrTable = [Double](repeating: 0, count: nDist)
        var windageTable = [Double](repeating: 0, count: nDist)
        var windageCorrTable = [Double](repeating: 0, count: nDist)
        var timeTable = [Double](repeating: 0, count: nDist)
        var vTable = [Double](repeating: 0, count: nDist)
        var vxTable = [Double](repeating: 0, count: nDist)
        var vyTable = [Double](repeating: 0, count: nDist)
        var energyTable = [Double](repeating: 0, count: nDist)

        for i in 0..<nDist {
            let pt = distances[i]
            dropsTable[i] = pt.drop.value
            dropCorrTable[i] = pt.dropCorrection.value
            windageTable[i] = pt.windage.value
            windageCorrTable[i] = pt.windageCorrection.value
            timeTable[i] = pt.travelTime.value
            vTable[i] = pt.velocity.value
            vxTable[i] = pt.velocityX.value
            vyTable[i] = pt.velocityY.value
            energyTable[i] = pt.energy.value
        }

        var interpDrops = [Double](repeating: 0, count: count)
        var interpDropCorrs = [Double](repeating: 0, count: count)
        var interpWindages = [Double](repeating: 0, count: count)
        var interpWindageCorrs = [Double](repeating: 0, count: count)
        var interpTimes = [Double](repeating: 0, count: count)
        var interpVs = [Double](repeating: 0, count: count)
        var interpVxs = [Double](repeating: 0, count: count)
        var interpVys = [Double](repeating: 0, count: count)
        var interpEnergies = [Double](repeating: 0, count: count)

        #if canImport(Accelerate)
        let nTable = vDSP_Length(distances.count)
        let nQuery = vDSP_Length(count)

        vDSP_vlintD(dropsTable, indices, 1, &interpDrops, 1, nQuery, nTable)
        vDSP_vlintD(dropCorrTable, indices, 1, &interpDropCorrs, 1, nQuery, nTable)
        vDSP_vlintD(windageTable, indices, 1, &interpWindages, 1, nQuery, nTable)
        vDSP_vlintD(windageCorrTable, indices, 1, &interpWindageCorrs, 1, nQuery, nTable)
        vDSP_vlintD(timeTable, indices, 1, &interpTimes, 1, nQuery, nTable)
        vDSP_vlintD(vTable, indices, 1, &interpVs, 1, nQuery, nTable)
        vDSP_vlintD(vxTable, indices, 1, &interpVxs, 1, nQuery, nTable)
        vDSP_vlintD(vyTable, indices, 1, &interpVys, 1, nQuery, nTable)
        vDSP_vlintD(energyTable, indices, 1, &interpEnergies, 1, nQuery, nTable)
        #else
        for i in 0..<count {
            let idx = indices[i]
            let base = Int(idx)
            let frac = idx - Double(base)
            if base >= distances.count - 1 {
                interpDrops[i] = dropsTable.last!
                interpDropCorrs[i] = dropCorrTable.last!
                interpWindages[i] = windageTable.last!
                interpWindageCorrs[i] = windageCorrTable.last!
                interpTimes[i] = timeTable.last!
                interpVs[i] = vTable.last!
                interpVxs[i] = vxTable.last!
                interpVys[i] = vyTable.last!
                interpEnergies[i] = energyTable.last!
            } else {
                interpDrops[i] = dropsTable[base] + frac * (dropsTable[base + 1] - dropsTable[base])
                interpDropCorrs[i] = dropCorrTable[base] + frac * (dropCorrTable[base + 1] - dropCorrTable[base])
                interpWindages[i] = windageTable[base] + frac * (windageTable[base + 1] - windageTable[base])
                interpWindageCorrs[i] = windageCorrTable[base] + frac * (windageCorrTable[base + 1] - windageCorrTable[base])
                interpTimes[i] = timeTable[base] + frac * (timeTable[base + 1] - timeTable[base])
                interpVs[i] = vTable[base] + frac * (vTable[base + 1] - vTable[base])
                interpVxs[i] = vxTable[base] + frac * (vxTable[base + 1] - vxTable[base])
                interpVys[i] = vyTable[base] + frac * (vyTable[base + 1] - vyTable[base])
                interpEnergies[i] = energyTable[base] + frac * (energyTable[base + 1] - energyTable[base])
            }
        }
        #endif

        let p0 = distances[0]
        var resultPoints = [Point]()
        resultPoints.reserveCapacity(count)

        for i in 0..<count {
            let d = validQueries[i].originalDistance
            resultPoints.append(
                Point(
                    range: d,
                    drop: Measurement(value: interpDrops[i], unit: p0.drop.unit),
                    dropCorrection: Measurement(value: interpDropCorrs[i], unit: p0.dropCorrection.unit),
                    windage: Measurement(value: interpWindages[i], unit: p0.windage.unit),
                    windageCorrection: Measurement(value: interpWindageCorrs[i], unit: p0.windageCorrection.unit),
                    travelTime: Measurement(value: interpTimes[i], unit: p0.travelTime.unit),
                    velocity: Measurement(value: interpVs[i], unit: p0.velocity.unit),
                    velocityX: Measurement(value: interpVxs[i], unit: p0.velocityX.unit),
                    velocityY: Measurement(value: interpVys[i], unit: p0.velocityY.unit),
                    energy: Measurement(value: interpEnergies[i], unit: p0.energy.unit),
                    spinDrift: nil,
                    coriolisHorizontal: nil,
                    coriolisVertical: nil
                )
            )
        }

        return resultPoints
    }

    /**
     Solves the trajectory using full rigid properties and aerodynamic coefficient functions (NATO STANAG 4355 4-DOF).
     */
    public static func solve(
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients? = nil,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double = 0.500,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        twist: Measurement<UnitLength>? = nil,
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
        return Solver4DOF.solve(
            properties: properties,
            coefficients: coefficients,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            shootingAngle: shootingAngle,
            twist: twist,
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

    /// Convenience alias forwarding to solve(properties: ...).
    @inlinable
    public static func solve4DOF(
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients? = nil,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double = 0.500,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        zeroRange: Measurement<UnitLength>,
        shootingAngle: Measurement<UnitAngle> = Measurement(value: 0, unit: .degrees),
        twist: Measurement<UnitLength>? = nil,
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
        return solve(
            properties: properties,
            coefficients: coefficients,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocity,
            sightHeight: sightHeight,
            zeroRange: zeroRange,
            shootingAngle: shootingAngle,
            twist: twist,
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

    // MARK: - DOPE Table Methods

    /**
     Generates a complete DOPE (Data On Previous Engagements) table covering all sampled points.
     Provides symmetric MRAD (0.1 MIL) and MOA (1/4 & 1/8 MOA) corrections for both elevation and windage.

     - Parameter speedOfSound: Ambient speed of sound for Mach calculations.
     - Returns: Array of `DOPERow` structures for each sampled trajectory point.
     */
    public func dopeTable(
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> [DOPERow] {
        distances.map { $0.dopeRow(speedOfSound: speedOfSound) }
    }

    /**
     Retrieves a single DOPE row interpolated at an arbitrary target distance.

     - Parameters:
       - distance: Target distance.
       - speedOfSound: Ambient speed of sound.
     - Returns: Interpolated `DOPERow` if distance is within trajectory bounds.
     */
    public func dopeRow(
        at distance: Measurement<UnitLength>,
        speedOfSound: Measurement<UnitSpeed> = Measurement(value: 1116.45, unit: .feetPerSecond)
    ) -> DOPERow? {
        guard let pt = getPoint(at: distance) else { return nil }
        return pt.dopeRow(speedOfSound: speedOfSound)
    }
}

