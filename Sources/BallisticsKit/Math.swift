//
//  Math.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

struct Math {

    static func degToRad(_ degrees: Double) -> Double {
        return degrees * .pi / 180
    }

    static func radToDeg(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }

    static func moaToRad(_ moa: Double) -> Double {
        return moa * (.pi / (180 * 60))
    }

    static func radToMOA(_ radians: Double) -> Double {
        return radians * (60 / .pi * 180)
    }
}
