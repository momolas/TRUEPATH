//
//  State4DOF.swift
//  BallisticsKit
//
//  Created by Antigravity on 08/10/2026.
//

import Foundation
import simd

/// Represents the 7-dimensional state vector of a projectile at a discrete time instant in NATO STANAG 4355 Modified Point Mass (4-DOF) simulations.
/// Accelerated with Apple SIMD hardware vectors for position and velocity.
public struct State4DOF: Sendable, Equatable, Hashable {

    // MARK: - Vector Storage (Earth frame)
    
    /// 3D position vector in feet: (x: downrange, y: vertical elevation, z: crossrange deflection).
    public var position: simd_double3
    
    /// 3D velocity vector in ft/s: (vx, vy, vz).
    public var velocity: simd_double3
    
    /// Axial spin rate around projectile longitudinal axis in rad/s (the 4th degree of freedom).
    public var p: Double
    
    /// Elapsed flight time from muzzle exit in seconds.
    public var time: Double

    // MARK: - Position Accessors (Earth frame, in feet)
    
    public var x: Double {
        get { position.x }
        set { position.x = newValue }
    }
    
    public var y: Double {
        get { position.y }
        set { position.y = newValue }
    }
    
    public var z: Double {
        get { position.z }
        set { position.z = newValue }
    }

    // MARK: - Linear Velocity Accessors (Earth frame, in ft/s)
    
    public var vx: Double {
        get { velocity.x }
        set { velocity.x = newValue }
    }
    
    public var vy: Double {
        get { velocity.y }
        set { velocity.y = newValue }
    }
    
    public var vz: Double {
        get { velocity.z }
        set { velocity.z = newValue }
    }

    // MARK: - Computed Properties

    /// Total linear speed V = sqrt(vx^2 + vy^2 + vz^2) in ft/s.
    @inlinable
    public var totalSpeedFPS: Double {
        simd_length(velocity)
    }

    /// Spin rate in revolutions per minute (RPM).
    @inlinable
    public var spinRateRPM: Double {
        (p * 60.0) / (2.0 * Double.pi)
    }

    public init(
        x: Double = 0,
        y: Double = 0,
        z: Double = 0,
        vx: Double,
        vy: Double,
        vz: Double = 0,
        p: Double,
        time: Double = 0
    ) {
        self.position = simd_double3(x, y, z)
        self.velocity = simd_double3(vx, vy, vz)
        self.p = p
        self.time = time
    }

    public init(
        position: simd_double3 = .zero,
        velocity: simd_double3,
        p: Double,
        time: Double = 0
    ) {
        self.position = position
        self.velocity = velocity
        self.p = p
        self.time = time
    }
}
