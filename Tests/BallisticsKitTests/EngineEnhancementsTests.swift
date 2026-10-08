//
//  EngineEnhancementsTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 01/10/2026.
//

import Foundation
import Testing
@testable import BallisticsKit

@Test func icaoAtmosphereLapseRate() {
    // Sea level base atmosphere: 59°F (15°C), 29.92 inHg
    let baseAtmosphere = Atmosphere(
        altitude: Measurement<UnitLength>(value: 0, unit: .feet),
        pressure: Measurement<UnitPressure>(value: 29.92, unit: .inchesOfMercury),
        temperature: Measurement<UnitTemperature>(value: 59, unit: .fahrenheit),
        relativeHumidity: 0.5
    )

    // Evaluate at 5,000 feet altitude (mountain firing position)
    let alt5000 = Measurement<UnitLength>(value: 5000, unit: .feet)
    let temp5000 = baseAtmosphere.temperature(atAltitude: alt5000).converted(to: .fahrenheit).value
    let press5000 = baseAtmosphere.pressure(atAltitude: alt5000).converted(to: .inchesOfMercury).value
    let sound5000 = baseAtmosphere.speedOfSound(atAltitude: alt5000).converted(to: .feetPerSecond).value

    // Expected lapse: ~3.566 °F per 1000 ft -> 59 - 5 * 3.566 = ~41.17 °F
    #expect(abs(temp5000 - 41.17) < 0.2)

    // Pressure at 5000 ft in ISA should be around 24.89 inHg (~843 hPa)
    #expect(press5000 < 25.5 && press5000 > 24.0)

    // Speed of sound decreases in cooler air
    let seaLevelSpeed = baseAtmosphere.speedOfSound.converted(to: .feetPerSecond).value
    #expect(sound5000 < seaLevelSpeed)
    #expect(sound5000 > 1050.0)

    // atAltitude factory creates consistent state
    let mountainAtmosphere = baseAtmosphere.atAltitude(alt5000)
    #expect(mountainAtmosphere.altitude.value == 5000)
    #expect(abs(mountainAtmosphere.temperature.converted(to: .fahrenheit).value - temp5000) < 1e-4)
}

@Test func windProfileCalculations() {
    // 1. Constant wind profile
    let constantProfile = WindProfile.constant(
        speed: Measurement(value: 10, unit: .milesPerHour),
        angle: 90
    )
    let (w1, a1) = constantProfile.wind(atRange: Measurement(value: 500, unit: .yards))
    #expect(w1.converted(to: .milesPerHour).value == 10)
    #expect(a1 == 90)

    // 2. Vertical boundary layer wind gradient (10 mph measured at 2m height)
    let gradientProfile = WindProfile.verticalGradient(
        referenceSpeed: Measurement(value: 10, unit: .milesPerHour),
        referenceHeight: Measurement(value: 2, unit: .meters),
        roughnessExponent: 0.143,
        angle: 90
    )

    // Near ground (0.5m) wind speed should be lower due to friction
    let (wLow, _) = gradientProfile.wind(
        atRange: Measurement(value: 300, unit: .yards),
        heightAboveGround: Measurement(value: 0.5, unit: .meters)
    )
    #expect(wLow.converted(to: .milesPerHour).value < 10.0)

    // High apex trajectory (4.0m) wind speed should be higher
    let (wHigh, _) = gradientProfile.wind(
        atRange: Measurement(value: 600, unit: .yards),
        heightAboveGround: Measurement(value: 4.0, unit: .meters)
    )
    #expect(wHigh.converted(to: .milesPerHour).value > 10.0)

    // 3. Segmented wind zones
    let segmentedProfile = WindProfile.segmented(zones: [
        .init(
            startRange: Measurement(value: 0, unit: .yards),
            endRange: Measurement(value: 300, unit: .yards),
            speed: Measurement(value: 5, unit: .milesPerHour),
            angle: 90
        ),
        .init(
            startRange: Measurement(value: 300, unit: .yards),
            endRange: Measurement(value: 800, unit: .yards),
            speed: Measurement(value: 15, unit: .milesPerHour),
            angle: 45
        )
    ])

    let (wNear, aNear) = segmentedProfile.wind(atRange: Measurement(value: 150, unit: .yards))
    #expect(wNear.converted(to: .milesPerHour).value == 5)
    #expect(aNear == 90)

    let (wFar, aFar) = segmentedProfile.wind(atRange: Measurement(value: 500, unit: .yards))
    #expect(wFar.converted(to: .milesPerHour).value == 15)
    #expect(aFar == 45)
}

@Test func bulletCatalogAndTrajectorySimulation() throws {
    // Query Hornady 6.5mm 140gr ELD-M
    let bullet = try #require(BulletCatalog.bullet(matching: "140gr"))
    #expect(bullet.manufacturer == "Hornady")
    #expect(bullet.caliber == "6.5mm")
    #expect(bullet.weight.converted(to: .grains).value == 140)
    #expect(bullet.bcG7 == 0.326)

    // Filter caliber
    let cal308Bullets = BulletCatalog.bullets(forCaliber: ".308")
    #expect(cal308Bullets.count >= 3)

    // Convert to 6-DOF properties
    let props = bullet.projectileProperties()
    #expect(props.massSlugs > 0)
    #expect(props.referenceAreaSquareFeet > 0)

    // Solve 3-DOF trajectory with catalog bullet
    let solution = Ballistics.solve3DOF(
        preferredDistanceUnit: .yards,
        dragFunction: .g7,
        dragCoefficient: bullet.bcG7 ?? 0.300,
        initialVelocity: Measurement(value: 2710, unit: .feetPerSecond),
        sightHeight: Measurement(value: 1.5, unit: .inches),
        zeroRange: Measurement(value: 100, unit: .yards),
        weight: bullet.weight,
        distanceStep: Measurement(value: 100, unit: .yards)
    )

    let point1000 = try #require(solution.getPoint(at: Measurement(value: 1000, unit: .yards)))
    // 6.5 Creedmoor at 1000 yards should remain supersonic (> 1120 fps) with 140gr ELD-M
    #expect(point1000.velocity.converted(to: .feetPerSecond).value > 1200)
    #expect(point1000.dropCorrection.converted(to: .minutesOfAngle).value > 20)
}

@Test func test308Winchester300mTrajectory() throws {
    // Cartridge: .308 Winchester - Sierra MatchKing 175gr HPBT
    let bullet = BulletCatalog.sierraMatchKing308_175gr
    let bcG7 = try #require(bullet.bcG7)
    
    // Weapon & Optic parameters
    let muzzleVelocity = Measurement<UnitSpeed>(value: 800, unit: .metersPerSecond) // ~2625 fps
    let sightHeight = Measurement<UnitLength>(value: 4.5, unit: .centimeters)
    let zeroRange = Measurement<UnitLength>(value: 100, unit: .meters)
    let targetRange = Measurement<UnitLength>(value: 300, unit: .meters)
    let barrelTwist = Measurement<UnitLength>(value: 11, unit: .inches) // 1:11" twist
    
    // Atmosphere & Environment
    let standardAtmosphere = Atmosphere(
        altitude: Measurement<UnitLength>(value: 0, unit: .meters),
        pressure: Measurement<UnitPressure>(value: 1013.25, unit: .hectopascals),
        temperature: Measurement<UnitTemperature>(value: 15, unit: .celsius),
        relativeHumidity: 0.5
    )
    let crossWind = Measurement<UnitSpeed>(value: 4.0, unit: .metersPerSecond) // 4 m/s full crosswind
    let windAngle = 90.0 // 3 o'clock
    
    // 1. Compute 3-DOF Solution with preferred unit in METERS
    let solution3DOF = Ballistics.solve3DOF(
        preferredDistanceUnit: .meters,
        dragFunction: .g7,
        dragCoefficient: bcG7,
        initialVelocity: muzzleVelocity,
        sightHeight: sightHeight,
        zeroRange: zeroRange,
        atmosphere: standardAtmosphere,
        windSpeed: crossWind,
        windAngle: windAngle,
        weight: bullet.weight,
        distanceStep: Measurement<UnitLength>(value: 10, unit: .meters),
        twist: barrelTwist,
        twistDirection: .right,
        bulletDiameter: bullet.diameter,
        bulletLength: bullet.length,
        maxRange: Measurement<UnitLength>(value: 350, unit: .meters)
    )
    
    // Verify 100m Zero Point
    let point100m = try #require(solution3DOF.getPoint(at: Measurement<UnitLength>(value: 100, unit: .meters)))
    let dropCorrectionAt100mMRAD = point100m.dropCorrection.converted(to: .milliradians).value
    #expect(abs(dropCorrectionAt100mMRAD) < 0.05) // Effectively 0 at zero range
    
    // Verify 300m Impact Point
    let point300m = try #require(solution3DOF.getPoint(at: targetRange))
    
    let dropMeters = point300m.drop.converted(to: .meters).value
    let dropCorrectionMRAD = point300m.dropCorrection.converted(to: .milliradians).value
    let dropCorrectionMOA = point300m.dropCorrection.converted(to: .minutesOfAngle).value
    let clicksElevation01MRAD = point300m.elevationClicks(.pointOneMRAD)
    let clicksElevation025MOA = point300m.elevationClicks(.oneFourthMOA)
    
    let windageMeters = point300m.windage.converted(to: .meters).value
    let windageCorrectionMRAD = point300m.windageCorrection.converted(to: .milliradians).value
    let clicksWindage01MRAD = point300m.windageClicks(.pointOneMRAD)
    
    let velocityMps = point300m.velocity.converted(to: .metersPerSecond).value
    let energyJoules = point300m.energy.converted(to: .joules).value
    let flightTime = point300m.travelTime.converted(to: .seconds).value
    
    // 2. Compute 6-DOF Adaptive Solution (DOPRI5)
    let solution6DOF = Ballistics.solve6DOF(
        properties: bullet.projectileProperties(),
        dragFunction: .g7,
        dragCoefficient: bcG7,
        initialVelocity: muzzleVelocity,
        sightHeight: sightHeight,
        zeroRange: zeroRange,
        twist: barrelTwist,
        twistDirection: .right,
        atmosphere: standardAtmosphere,
        windSpeed: crossWind,
        windAngle: windAngle,
        distanceStep: Measurement<UnitLength>(value: 10, unit: .meters),
        preferredDistanceUnit: .meters,
        tolerance: .highPrecision,
        maxRange: Measurement<UnitLength>(value: 350, unit: .meters)
    )
    
    let point6DOF300m = try #require(solution6DOF.getPoint(at: targetRange))
    let drop6DOF = point6DOF300m.drop.converted(to: .meters).value
    let vel6DOF = point6DOF300m.velocity.converted(to: .metersPerSecond).value
    
    // Assertions based on verified .308 175gr ballistics:
    // Drop at 300m (with 100m zero) is -41.2 cm
    #expect(abs(dropMeters - (-0.412)) < 0.02)
    // Elevation correction is 1.37 MRAD (4.72 MOA)
    #expect(abs(dropCorrectionMRAD - 1.37) < 0.05)
    #expect(abs(dropCorrectionMOA - 4.72) < 0.1)
    #expect(clicksElevation01MRAD == 14)
    #expect(clicksElevation025MOA == 19)
    
    // Wind drift with 4 m/s at 300m is ~7.7 cm (0.26 MRAD)
    #expect(abs(windageMeters - 0.077) < 0.02)
    #expect(abs(windageCorrectionMRAD - 0.26) < 0.03)
    #expect(clicksWindage01MRAD == 3)
    
    // Flight dynamics
    #expect(abs(flightTime - 0.394) < 0.02)
    #expect(velocityMps > 700 && velocityMps < 740) // Supersonic Mach > 2.1
    #expect(energyJoules > 2800 && energyJoules < 3100) // ~2960 J
    
    // 6-DOF validation
    #expect(abs(drop6DOF - (-0.475)) < 0.03)
    #expect(vel6DOF > 620 && vel6DOF < 670)
}
