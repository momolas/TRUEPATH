//
//  AdvancedBallisticsExtensionsTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 09/10/2026.
//

import Testing
import Foundation
@testable import BallisticsKit

struct AdvancedBallisticsExtensionsTests {

    @Test
    func testDensityAltitudeCalculation() {
        // Sea level standard conditions: 59°F, 29.92 inHg -> DA ≈ 0 ft
        let stdAtmosphere = Atmosphere(
            altitude: Measurement(value: 0, unit: .feet),
            pressure: Measurement(value: 29.921, unit: .inchesOfMercury),
            temperature: Measurement(value: 59, unit: .fahrenheit)
        )
        let da = stdAtmosphere.densityAltitude.converted(to: .feet).value
        #expect(abs(da) < 100.0)

        // Hot summer day at 5,000 ft elevation: 95°F, 24.8 inHg -> High DA (> 8,000 ft)
        let hotHighAtmosphere = Atmosphere(
            altitude: Measurement(value: 5000, unit: .feet),
            pressure: Measurement(value: 24.896, unit: .inchesOfMercury),
            temperature: Measurement(value: 95, unit: .fahrenheit)
        )
        let hotDA = hotHighAtmosphere.densityAltitude.converted(to: .feet).value
        #expect(hotDA > 7500)
    }

    @Test
    func testAtmosphereFromDensityAltitude() {
        let targetDA = Measurement(value: 4000, unit: UnitLength.feet)
        let atm = Atmosphere.fromDensityAltitude(targetDA)
        let computedDA = atm.densityAltitude.converted(to: .feet).value
        #expect(abs(computedDA - 4000.0) < 150.0)
    }

    @Test
    func testAtmosphereFromStationPressure() {
        let stationP = Measurement(value: 25.5, unit: UnitPressure.inchesOfMercury)
        let temp = Measurement(value: 68, unit: UnitTemperature.fahrenheit)
        let atm = Atmosphere.fromStationPressure(stationPressure: stationP, temperature: temp)

        #expect(atm.pressure.value == 25.5)
        #expect(atm.temperature.value == 68)
        #expect(atm.densityAltitude.value > 0)
    }

    @Test
    func testDidionLagTime() {
        let v0 = Measurement(value: 2700, unit: UnitSpeed.feetPerSecond)
        let point = Point(
            range: Measurement(value: 600, unit: .yards), // 1800 ft
            drop: Measurement(value: -80, unit: .inches),
            dropCorrection: Measurement(value: 12.7, unit: .minutesOfAngle),
            windage: Measurement(value: 20, unit: .inches),
            windageCorrection: Measurement(value: 3.2, unit: .minutesOfAngle),
            travelTime: Measurement(value: 0.85, unit: .seconds), // Flight time in air
            velocity: Measurement(value: 1750, unit: .feetPerSecond),
            velocityX: Measurement(value: 1745, unit: .feetPerSecond),
            velocityY: Measurement(value: -30, unit: .feetPerSecond),
            energy: Measurement(value: 1200, unit: .footPounds)
        )

        // Vacuum time = 1800 ft / 2700 fps = 0.6667 s
        // Actual flight time = 0.85 s
        // Lag time = 0.85 - 0.6667 = ~0.1833 s
        let lag = point.lagTime(initialVelocity: v0).converted(to: .seconds).value
        #expect(lag > 0.15 && lag < 0.22)
    }

    @Test
    func testMcCoyPhysicalAerodynamicJump() {
        let v0 = Measurement(value: 2600, unit: UnitSpeed.feetPerSecond)
        let crosswind = Measurement(value: 10, unit: UnitSpeed.milesPerHour) // from left
        let twist = Measurement(value: 10, unit: UnitLength.inches)

        let properties = ProjectileProperties(
            weight: Measurement(value: 175, unit: .grains),
            diameter: Measurement(value: 0.308, unit: .inches),
            length: Measurement(value: 1.24, unit: .inches)
        )

        let coeffs = AerodynamicCoefficients.synthesize(
            properties: properties,
            dragFunction: .g7,
            dragCoefficient: 0.245
        )

        let jump = AerodynamicJump.physicalJumpAngle(
            crosswindSpeed: crosswind,
            initialVelocity: v0,
            properties: properties,
            coefficients: coeffs,
            twist: twist,
            twistDirection: .right
        )

        // Physical aerodynamic jump should be positive for right-hand twist and left crosswind, typically 0.05 to 0.25 MOA
        let moaVal = jump.converted(to: .minutesOfAngle).value
        #expect(moaVal > 0.01)
        #expect(moaVal < 0.50)
    }

    @Test
    func testDynamicWindProfileInSolver4DOF() {
        let v0 = Measurement(value: 2750, unit: UnitSpeed.feetPerSecond)
        let zero = Measurement(value: 100, unit: UnitLength.yards)
        let sightH = Measurement(value: 1.5, unit: UnitLength.inches)

        // Trajectory with Hellman vertical wind shear gradient
        let gradientProfile = WindProfile.verticalGradient(
            referenceSpeed: Measurement(value: 10, unit: .milesPerHour),
            referenceHeight: Measurement(value: 2, unit: .meters),
            roughnessExponent: 0.143,
            angle: 90
        )

        let solGradient = Ballistics.solve(
            preferredDistanceUnit: .yards,
            dragFunction: .g7,
            dragCoefficient: 0.265,
            initialVelocity: v0,
            sightHeight: sightH,
            zeroRange: zero,
            windProfile: gradientProfile,
            distanceStep: Measurement(value: 100, unit: .yards),
            maxRange: Measurement(value: 650, unit: .yards)
        )

        // Trajectory with zero wind
        let solCalm = Ballistics.solve(
            preferredDistanceUnit: .yards,
            dragFunction: .g7,
            dragCoefficient: 0.265,
            initialVelocity: v0,
            sightHeight: sightH,
            zeroRange: zero,
            windSpeed: Measurement(value: 0, unit: .milesPerHour),
            distanceStep: Measurement(value: 100, unit: .yards),
            maxRange: Measurement(value: 650, unit: .yards)
        )

        let ptGradient = solGradient.getPoint(at: Measurement(value: 600, unit: .yards))
        let ptCalm = solCalm.getPoint(at: Measurement(value: 600, unit: .yards))

        #expect(ptGradient != nil)
        #expect(ptCalm != nil)

        if let ptG = ptGradient, let ptC = ptCalm {
            // Windage under shear must be distinctly non-zero (> 5.0 inches), while calm windage is near zero (< 1.0 inch)
            #expect(abs(ptG.windage.converted(to: .inches).value) > 5.0)
            #expect(abs(ptC.windage.converted(to: .inches).value) < 1.0)
        }
    }
}

