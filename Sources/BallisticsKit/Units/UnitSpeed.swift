//
//  UnitSpeed.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 04/12/2024.
//

import Foundation

extension UnitSpeed {
    public static let feetPerSecond: UnitSpeed = .init(symbol: "f/s", converter: UnitConverterLinear(coefficient: 0.3048))
}
