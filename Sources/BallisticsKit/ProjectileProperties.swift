//
//  ProjectileProperties.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents the physical and geometric rigid-body properties of a bullet for 6-DOF simulations.
public struct ProjectileProperties: Sendable, Equatable, Hashable {

    /// The bullet mass (weight).
    public let weight: Measurement<UnitMass>

    /// The bullet caliber (outer diameter).
    public let diameter: Measurement<UnitLength>

    /// The overall total bullet length.
    public let length: Measurement<UnitLength>

    /// The length of the bullet's nose / ogive section.
    public let noseLength: Measurement<UnitLength>

    /// The length of the bullet's boat-tail section.
    public let boatTailLength: Measurement<UnitLength>

    /// The boat-tail half-angle.
    public let boatTailAngle: Measurement<UnitAngle>

    /// Center of gravity position (distance from bullet base).
    public let centerOfGravityFromBase: Measurement<UnitLength>

    /// Axial moment of inertia (around spin axis, in lb·ft² or kg·m²).
    public let axialInertia: Double

    /// Transverse moment of inertia (around pitch/yaw axes, in lb·ft² or kg·m²).
    public let transverseInertia: Double

    /// Reference cross-sectional area: S = pi * (d / 2)^2 in square feet.
    public var referenceAreaSquareFeet: Double {
        let radiusFeet = (diameter.converted(to: .inches).value / 2.0) / 12.0
        return Double.pi * radiusFeet * radiusFeet
    }

    /// Mass in slugs: m (lb) / 32.174
    public var massSlugs: Double {
        let weightPounds = weight.converted(to: .grains).value / 7000.0
        return weightPounds / 32.17405
    }

    public init(
        weight: Measurement<UnitMass>,
        diameter: Measurement<UnitLength>,
        length: Measurement<UnitLength>,
        noseLength: Measurement<UnitLength>? = nil,
        boatTailLength: Measurement<UnitLength>? = nil,
        boatTailAngle: Measurement<UnitAngle>? = nil,
        centerOfGravityFromBase: Measurement<UnitLength>? = nil,
        axialInertia: Double? = nil,
        transverseInertia: Double? = nil
    ) {
        self.weight = weight
        self.diameter = diameter
        self.length = length

        let lengthInches = length.converted(to: .inches).value
        let diamInches = diameter.converted(to: .inches).value

        // Default nose length ~ 55% of total length for tangent/secant ogives
        let defaultNose = noseLength ?? Measurement(value: lengthInches * 0.55, unit: .inches)
        self.noseLength = defaultNose

        // Default boat tail ~ 15% of length
        let defaultBT = boatTailLength ?? Measurement(value: lengthInches * 0.15, unit: .inches)
        self.boatTailLength = defaultBT

        // Default boat tail angle ~ 7.5 degrees
        let defaultBTAngle = boatTailAngle ?? Measurement(value: 7.5, unit: .degrees)
        self.boatTailAngle = defaultBTAngle

        // Default CG ~ 42% from base for boat-tail match bullets
        let defaultCG = centerOfGravityFromBase ?? Measurement(value: lengthInches * 0.42, unit: .inches)
        self.centerOfGravityFromBase = defaultCG

        // Calculate physical moments of inertia if not supplied
        let weightPounds = weight.converted(to: .grains).value / 7000.0
        let mSlugs = weightPounds / 32.17405
        let rFeet = (diamInches / 2.0) / 12.0
        let lFeet = lengthInches / 12.0

        // Ix = 0.5 * m * r^2 * k_dens (k_dens ~ 0.85 for jacketed lead core)
        let defaultIx = axialInertia ?? (0.5 * mSlugs * rFeet * rFeet * 0.85)
        self.axialInertia = defaultIx

        // Iy = m * (r^2/4 + l^2/12) * k_shape
        let defaultIy = transverseInertia ?? (mSlugs * ((rFeet * rFeet / 4.0) + (lFeet * lFeet / 12.0)) * 0.90)
        self.transverseInertia = defaultIy
    }
}
