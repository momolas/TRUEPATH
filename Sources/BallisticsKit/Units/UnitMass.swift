//
//  UnitMass.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 10/12/2024.
//

import Foundation

extension UnitMass {
    public static let grains: UnitMass = UnitMass(symbol: "gr", converter: UnitConverterLinear(coefficient: 6.47989e-5))
}
