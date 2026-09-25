//
//  Ballistics.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

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
    public static func solve3DOF(
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
        return Solver3DOF.solve(
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

    /// Alias for solve3DOF for backwards compatibility.
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
        solve3DOF(
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
     Solves a high-fidelity 6-DOF rigid-body trajectory (Lapua Ballistics standard) using 4th-order Runge-Kutta integration.
     */
    public static func solve6DOF(
        properties: ProjectileProperties,
        coefficients: AerodynamicCoefficients? = nil,
        dragFunction: DragFunction = .g7,
        dragCoefficient: Double = 0.500,
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
        let aeroCoeffs = coefficients ?? AerodynamicCoefficients.synthesize(
            properties: properties,
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient
        )

        return Solver6DOF.solve(
            properties: properties,
            coefficients: aeroCoeffs,
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
            preferredDistanceUnit: preferredDistanceUnit
        )
    }
}
