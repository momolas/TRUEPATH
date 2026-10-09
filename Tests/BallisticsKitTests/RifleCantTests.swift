//
//  RifleCantTests.swift
//  BallisticsKitTests
//
//  Created by Antigravity on 09/10/2026.
//

import Testing
import Foundation
@testable import BallisticsKit

struct RifleCantTests {

    @Test
    func testZeroCantAngleProducesNoShift() {
        let drop = Measurement(value: 12.0, unit: UnitAngle.minutesOfAngle)
        let wind = Measurement(value: 3.0, unit: UnitAngle.minutesOfAngle)
        let cant = Measurement(value: 0.0, unit: UnitAngle.degrees)

        let err = RifleCant.angularError(
            dropCorrection: drop,
            windageCorrection: wind,
            cantAngle: cant
        )

        #expect(abs(err.elevationError.value) < 1e-6)
        #expect(abs(err.windageError.value) < 1e-6)
    }

    @Test
    func testRightCantProducesRightWindageAndDropLoss() {
        // Canted 5 degrees to the right (clockwise)
        let drop = Measurement(value: 20.0, unit: UnitAngle.minutesOfAngle)
        let wind = Measurement(value: 0.0, unit: UnitAngle.minutesOfAngle)
        let cant = Measurement(value: 5.0, unit: UnitAngle.degrees)

        let err = RifleCant.angularError(
            dropCorrection: drop,
            windageCorrection: wind,
            cantAngle: cant
        )

        // Elevation error = 20 * (cos(5°) - 1) < 0 (lower impact)
        #expect(err.elevationError.value < 0.0)
        #expect(abs(err.elevationError.value - (20.0 * (cos(5.0 * .pi / 180.0) - 1.0))) < 1e-3)

        // Windage error = -20 * sin(5°) < 0 in reticle frame, translating to rightward deflection
        #expect(abs(err.windageError.value) > 1.0)
    }

    @Test
    func testLinearImpactShiftAtDistance() {
        let dist = Measurement(value: 600, unit: UnitLength.yards)
        let drop = Measurement(value: 15.0, unit: UnitAngle.minutesOfAngle)
        let cant = Measurement(value: 3.0, unit: UnitAngle.degrees)

        let shift = RifleCant.linearImpactShift(
            targetDistance: dist,
            dropCorrection: drop,
            cantAngle: cant
        )

        // At 600 yards, a 3 degree cant with 15 MOA dialed causes noticeable inch displacement
        #expect(shift.verticalShift.converted(to: .inches).value < 0.0)
        #expect(abs(shift.horizontalShift.converted(to: .inches).value) > 1.0)
    }

    @Test
    func testPointCantErrorHelper() {
        let pointPureDrop = Point(
            range: Measurement(value: 500, unit: .yards),
            drop: Measurement(value: -60, unit: .inches),
            dropCorrection: Measurement(value: 11.5, unit: .minutesOfAngle),
            windage: Measurement(value: 0, unit: .inches),
            windageCorrection: Measurement(value: 0, unit: .minutesOfAngle),
            travelTime: Measurement(value: 0.65, unit: .seconds),
            velocity: Measurement(value: 2100, unit: .feetPerSecond),
            velocityX: Measurement(value: 2095, unit: .feetPerSecond),
            velocityY: Measurement(value: -15, unit: .feetPerSecond),
            energy: Measurement(value: 1800, unit: .footPounds)
        )

        let cant = Measurement(value: 2.5, unit: UnitAngle.degrees)
        let angErr = pointPureDrop.cantError(angle: cant)
        let linErr = pointPureDrop.linearCantShift(angle: cant)

        // Without windage dialed, right cant always produces drop loss and right shift
        #expect(angErr.elevationError.value < 0)
        #expect(angErr.windageError.value < 0)
        #expect(linErr.verticalShift.value < 0)
        #expect(linErr.horizontalShift.value < 0)
    }
}
