//
//  DragFunction.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents the aerodynamic drag model used to simulate projectile deceleration.
public enum DragFunction: String, Sendable, CaseIterable, Codable {
    /// Standard G1 model (Ingalls), suitable for flat-based, short-ogive sporting projectiles.
    case g1 = "G1"

    /// Standard G2 model, for long conical projectiles (2-caliber ogive, 5.4-caliber boat-tail).
    case g2 = "G2"

    /// Standard G5 model, for moderate low-drag boat-tail bullets (6-caliber tangent ogive, 7.5° boat-tail).
    case g5 = "G5"

    /// Standard G6 model, for flat-based target bullets (6-caliber secant ogive).
    case g6 = "G6"

    /// Standard G7 model, optimized for modern low-drag, boat-tail long-range rifle bullets (VLD).
    case g7 = "G7"

    /// Standard G8 model, for flat-based target bullets with long 10-caliber secant ogive.
    case g8 = "G8"
}
