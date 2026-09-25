//
//  State6DOF.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation
import simd

/// Represents the 12-dimensional state vector of a rigid-body projectile at a discrete time instant in 6-DOF simulations.
/// Accelerated with Apple SIMD hardware vectors for position and linear velocity.
public struct State6DOF: Sendable, Equatable, Hashable {

    // MARK: - Vector Storage (Earth frame)
    public var position: simd_double3
    public var velocity: simd_double3

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

    // MARK: - Angular Orientation (Euler angles in radians: Pitch, Yaw, Roll)
    public var pitch: Double
    public var yaw: Double
    public var roll: Double

    // MARK: - Angular Rates (Body frame, in rad/s: Roll p, Pitch q, Yaw r)
    public var p: Double
    public var q: Double
    public var r: Double

    // MARK: - Computed Properties

    /// Total linear speed V = sqrt(vx^2 + vy^2 + vz^2) in ft/s.
    public var totalSpeedFPS: Double {
        simd_length(velocity)
    }

    /// Spin rate in revolutions per minute (RPM).
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
        pitch: Double,
        yaw: Double = 0,
        roll: Double = 0,
        p: Double,
        q: Double = 0,
        r: Double = 0
    ) {
        self.position = simd_double3(x, y, z)
        self.velocity = simd_double3(vx, vy, vz)
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
        self.p = p
        self.q = q
        self.r = r
    }

    public init(
        position: simd_double3 = .zero,
        velocity: simd_double3,
        pitch: Double,
        yaw: Double = 0,
        roll: Double = 0,
        p: Double,
        q: Double = 0,
        r: Double = 0
    ) {
        self.position = position
        self.velocity = velocity
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
        self.p = p
        self.q = q
        self.r = r
    }
}
