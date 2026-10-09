//
//  Atmosphere.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

public struct Atmosphere: Sendable, Equatable, Hashable {

    public let altitude: Measurement<UnitLength>
    public let pressure: Measurement<UnitPressure>
    public let temperature: Measurement<UnitTemperature>
    public let relativeHumidity: Double

    /// Calculates the local speed of sound in air based on the ambient temperature.
    /// Uses the thermodynamic formula: c = 49.0223 * sqrt(T_Rankine) in ft/s.
    public var speedOfSound: Measurement<UnitSpeed> {
        let tempFahrenheit = temperature.converted(to: .fahrenheit).value
        let tempRankine = max(1.0, tempFahrenheit + 459.67)
        let speedFPS = 49.0223 * sqrt(tempRankine)
        return Measurement(value: speedFPS, unit: .feetPerSecond)
    }

    /// Ambient air density in slugs per cubic foot, adjusted for altitude, temperature, pressure and humidity.
    public var airDensitySlugFt3: Double {
        let seaLevelDensity = 0.0023769 // slug / ft^3 at standard ICAO sea level
        let factor = adjustCoefficient(dragCoefficient: 1.0)
        return max(0.0001, seaLevelDensity / max(1e-6, factor))
    }

    public init(
        altitude: Measurement<UnitLength> = Measurement<UnitLength>(value: 0, unit: .meters),
        pressure: Measurement<UnitPressure> = Measurement<UnitPressure>(value: 29.92, unit: .inchesOfMercury),
        temperature: Measurement<UnitTemperature> = Measurement<UnitTemperature>(value: 10, unit: .celsius),
        relativeHumidity: Double = 0
    ) {
        self.altitude = altitude
        self.pressure = pressure
        self.temperature = temperature
        self.relativeHumidity = relativeHumidity
    }

    /**
     Adjusts the ballistic drag coefficient based on atmospheric conditions.

     This method calculates a corrected drag coefficient by accounting for changes in altitude, barometric pressure, temperature, and relative humidity. These factors influence air density and, consequently, the drag force acting on a projectile.

     - Parameters:
       - dragCoefficient: The base drag coefficient of the projectile, typically measured under standard atmospheric conditions.

     - Returns:
       A `Double` representing the adjusted drag coefficient for the given atmospheric conditions.
     */
    public func adjustCoefficient(
        dragCoefficient: Double
    ) -> Double {
        let altitudeFeet = altitude.converted(to: .feet).value
        let temperatureFahrenheit = temperature.converted(to: .fahrenheit).value
        let pressureInHg = pressure.converted(to: .inchesOfMercury).value
        let fa = calcFA(altitude: altitudeFeet)
        let ft = calcFT(temperature: temperatureFahrenheit, altitude: altitudeFeet)
        let fr = calcFR(temperature: temperatureFahrenheit, pressure: pressureInHg, relativeHumidity: relativeHumidity)
        let fp = calcFP(pressure: pressureInHg)
        let cd = fa * (1 + ft - fp) * fr
        return dragCoefficient * cd
    }

    // Drag coefficient atmospheric corrections
    private func calcFR(temperature: Double, pressure: Double, relativeHumidity: Double) -> Double {
        let vpw = 4e-6 * pow(temperature, 3) - 0.0004 * pow(temperature, 2) + 0.0234 * temperature - 0.2517
        let frh = 0.995 * (pressure / (pressure - (0.3783 * relativeHumidity * vpw)))
        return frh
    }

    private func calcFP(pressure: Double) -> Double {
        let pStd = 29.921 // Standard pressure at sea level in inHg
        let fp = (pressure - pStd) / pStd
        return fp
    }

    private func calcFT(temperature: Double, altitude: Double) -> Double {
        let tStd = -0.0036 * altitude + 59
        let ft = (temperature - tStd) / (459.6 + tStd)
        return ft
    }

    private func calcFA(altitude: Double) -> Double {
        let fa = -4e-15 * pow(altitude, 3) + 4e-10 * pow(altitude, 2) - 3e-5 * altitude + 1
        return 1 / fa
    }

    // MARK: - ICAO / ISA Dynamic Atmosphere Extensions

    /// Computes ambient temperature at a different altitude using the ICAO / ISA Standard Atmosphere lapse rate (-6.5 K / 1000m or -3.566 °F / 1000ft in the troposphere).
    public func temperature(atAltitude targetAltitude: Measurement<UnitLength>) -> Measurement<UnitTemperature> {
        let baseAltFeet = altitude.converted(to: .feet).value
        let targetAltFeet = targetAltitude.converted(to: .feet).value
        let deltaFeet = targetAltFeet - baseAltFeet

        let baseTempF = temperature.converted(to: .fahrenheit).value
        // Troposphere lapse rate: -3.56616 °F per 1000 ft (0.00356616 °F/ft)
        let lapseRatePerFoot = 0.00356616
        let targetTempF = baseTempF - (deltaFeet * lapseRatePerFoot)

        return Measurement(value: targetTempF, unit: .fahrenheit).converted(to: temperature.unit)
    }

    /// Computes barometric pressure at a different altitude using the ICAO standard barometric formula.
    public func pressure(atAltitude targetAltitude: Measurement<UnitLength>) -> Measurement<UnitPressure> {
        let baseAltFeet = altitude.converted(to: .feet).value
        let targetAltFeet = targetAltitude.converted(to: .feet).value
        let deltaFeet = targetAltFeet - baseAltFeet

        let baseTempF = temperature.converted(to: .fahrenheit).value
        let baseTempRankine = max(1.0, baseTempF + 459.67)

        let basePressureInHg = pressure.converted(to: .inchesOfMercury).value
        let lapseRatePerFoot = 0.00356616

        // P = P0 * (1 - (L * deltaH) / T0) ^ (g * M / (R * L)) where exponent ≈ 5.25588
        let term = 1.0 - (lapseRatePerFoot * deltaFeet) / baseTempRankine
        let clampedTerm = max(1e-4, term)
        let targetPressureInHg = basePressureInHg * pow(clampedTerm, 5.25588)

        return Measurement(value: targetPressureInHg, unit: .inchesOfMercury).converted(to: pressure.unit)
    }

    /// Computes speed of sound at a given altitude accounting for the atmospheric temperature lapse.
    public func speedOfSound(atAltitude targetAltitude: Measurement<UnitLength>) -> Measurement<UnitSpeed> {
        let targetTempF = temperature(atAltitude: targetAltitude).converted(to: .fahrenheit).value
        let tempRankine = max(1.0, targetTempF + 459.67)
        let speedFPS = 49.0223 * sqrt(tempRankine)
        return Measurement(value: speedFPS, unit: .feetPerSecond)
    }

    /// Returns a new `Atmosphere` instance adjusted for a different altitude according to ICAO standard lapse rates.
    public func atAltitude(_ newAltitude: Measurement<UnitLength>) -> Atmosphere {
        let newTemp = temperature(atAltitude: newAltitude)
        let newPress = pressure(atAltitude: newAltitude)
        return Atmosphere(
            altitude: newAltitude,
            pressure: newPress,
            temperature: newTemp,
            relativeHumidity: relativeHumidity
        )
    }

    // MARK: - Density Altitude & Station Pressure

    /// Computes the Density Altitude (DA) corresponding to this atmospheric state.
    /// Density Altitude is the altitude in the International Standard Atmosphere (ISA) where air density equals ambient air density.
    public var densityAltitude: Measurement<UnitLength> {
        let pInHg = pressure.converted(to: .inchesOfMercury).value
        let tC = temperature.converted(to: .celsius).value

        // Pressure altitude: Hp = 145366.45 * (1 - (P / 29.921)^0.190284) ft
        let pressureAltFeet = 145366.45 * (1.0 - pow(max(1e-4, pInHg / 29.921), 0.190284))
        // ISA standard temperature at pressure altitude: T_ISA = 15°C - 0.0019812 * Hp
        let isaTempC = 15.0 - (0.0019812 * pressureAltFeet)
        // Standard density altitude approximation: DA = Hp + 118.8 * (T_ambient - T_ISA)
        let daFeet = pressureAltFeet + 118.8 * (tC - isaTempC)
        return Measurement(value: daFeet, unit: .feet)
    }

    /// Initializes an `Atmosphere` directly from a specified Density Altitude (DA).
    /// Assumes standard ISA atmosphere at that density altitude (relative humidity defaults to 0.5).
    public static func fromDensityAltitude(
        _ densityAltitude: Measurement<UnitLength>,
        relativeHumidity: Double = 0.5
    ) -> Atmosphere {
        let daFeet = densityAltitude.converted(to: .feet).value
        // In standard ISA, temperature at DA: T = 59°F - 0.00356616 * DA
        let tempF = 59.0 - 0.00356616 * daFeet
        // Standard ISA pressure: P = 29.921 * (1 - 0.00356616 * DA / 518.67)^5.25588
        let term = max(1e-4, 1.0 - (0.00356616 * daFeet) / 518.67)
        let pInHg = 29.921 * pow(term, 5.25588)
        return Atmosphere(
            altitude: densityAltitude,
            pressure: Measurement(value: pInHg, unit: .inchesOfMercury),
            temperature: Measurement(value: tempF, unit: .fahrenheit),
            relativeHumidity: relativeHumidity
        )
    }

    /// Initializes an `Atmosphere` from absolute Station Pressure (e.g., direct Kestrel 5700 or Apple Watch barometric sensor).
    /// Station pressure is the actual uncorrected ambient pressure at the current location.
    public static func fromStationPressure(
        stationPressure: Measurement<UnitPressure>,
        temperature: Measurement<UnitTemperature>,
        altitude: Measurement<UnitLength> = Measurement(value: 0, unit: .meters),
        relativeHumidity: Double = 0.5
    ) -> Atmosphere {
        Atmosphere(
            altitude: altitude,
            pressure: stationPressure,
            temperature: temperature,
            relativeHumidity: relativeHumidity
        )
    }
}

