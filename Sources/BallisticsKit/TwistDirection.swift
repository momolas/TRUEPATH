//
//  TwistDirection.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// The rifling twist direction of the firearm barrel.
public enum TwistDirection: String, Sendable, CaseIterable, Codable {
    /// Right-hand rifling (clockwise from shooter's perspective). Deflects bullet to the right.
    case right

    /// Left-hand rifling (counter-clockwise from shooter's perspective). Deflects bullet to the left.
    case left

    /// Multiplier used in lateral deflection formulas (+1 for right, -1 for left).
    public var sign: Double {
        switch self {
        case .right: return 1.0
        case .left: return -1.0
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("left") || normalized.contains("gaucher") {
            self = .left
        } else {
            self = .right
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
