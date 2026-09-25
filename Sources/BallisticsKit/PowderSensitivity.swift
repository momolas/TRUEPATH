//
//  PowderSensitivity.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Utilities for calculating ammunition muzzle velocity variation as a function of propellant powder temperature.
public struct PowderSensitivity: Sendable, Equatable, Hashable {

    /**
     Adjusts the muzzle velocity for ambient / ammunition temperature based on a linear powder sensitivity coefficient.

     `V = V_base + sensitivity * (T - T_base)`

     - Parameters:
       - baseVelocity: The muzzle velocity measured at the reference temperature.
       - baseTemperature: The reference ammunition temperature (e.g. 59°F / 15°C).
       - currentTemperature: The actual current ammunition temperature.
       - sensitivityFPSPerDegreeF: The rate of change of muzzle velocity in ft/s per °F (typically +0.5 to +2.5 fps/°F).

     - Returns:
       The adjusted muzzle velocity.
     */
    public static func adjustedVelocity(
        baseVelocity: Measurement<UnitSpeed>,
        baseTemperature: Measurement<UnitTemperature>,
        currentTemperature: Measurement<UnitTemperature>,
        sensitivityFPSPerDegreeF: Double
    ) -> Measurement<UnitSpeed> {
        let v0FPS = baseVelocity.converted(to: .feetPerSecond).value
        let t0F = baseTemperature.converted(to: .fahrenheit).value
        let tF = currentTemperature.converted(to: .fahrenheit).value

        let deltaT = tF - t0F
        let deltaV = sensitivityFPSPerDegreeF * deltaT
        let adjustedFPS = max(100.0, v0FPS + deltaV)

        return Measurement(value: adjustedFPS, unit: .feetPerSecond)
    }

    /**
     Calculates the powder sensitivity coefficient from two chronograph velocity readings at different temperatures.

     `sensitivity = (V2 - V1) / (T2 - T1)`

     - Parameters:
       - velocity1: Muzzle velocity at temperature 1.
       - temperature1: Temperature 1.
       - velocity2: Muzzle velocity at temperature 2.
       - temperature2: Temperature 2.

     - Returns:
       The powder temperature sensitivity coefficient in fps per °F.
     */
    public static func calculateSensitivity(
        velocity1: Measurement<UnitSpeed>,
        temperature1: Measurement<UnitTemperature>,
        velocity2: Measurement<UnitSpeed>,
        temperature2: Measurement<UnitTemperature>
    ) -> Double {
        let v1 = velocity1.converted(to: .feetPerSecond).value
        let v2 = velocity2.converted(to: .feetPerSecond).value
        let t1 = temperature1.converted(to: .fahrenheit).value
        let t2 = temperature2.converted(to: .fahrenheit).value

        guard abs(t2 - t1) > 1e-4 else { return 0 }
        return (v2 - v1) / (t2 - t1)
    }
}
