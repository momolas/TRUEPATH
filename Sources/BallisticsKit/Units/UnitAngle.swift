//
//  UnitAngle.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 04/12/2024.
//

import Foundation

extension UnitAngle {
    public static let minutesOfAngle: UnitAngle = UnitAngle(symbol: "MOA", converter: UnitConverterLinear(coefficient: 1/60))
    public static let milliradians: UnitAngle = UnitAngle(symbol: "MIL", converter: UnitConverterLinear(coefficient: 0.0572958))
}
