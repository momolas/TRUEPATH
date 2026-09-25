//
//  UnitEnergy.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 10/12/2024.
//

import Foundation

extension UnitEnergy {
    public static let footPounds: UnitEnergy = UnitEnergy(symbol: "ft⋅lbf", converter: UnitConverterLinear(coefficient: 1.35582))
}
