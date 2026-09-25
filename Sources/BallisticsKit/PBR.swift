//
//  PBR.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents the Point Blank Range (PBR) calculation results for a given vital zone target size.
public struct PBR: Sendable, Equatable, Hashable {

    /// The near zero distance where the projectile intersects the line of sight on the way up (in yards).
    public let nearZeroYards: Int

    /// The far zero distance where the projectile intersects the line of sight on the way down (in yards).
    public let farZeroYards: Int

    /// The minimum range where the trajectory enters the vital zone (in yards).
    public let minPBRYards: Int

    /// The maximum point blank range where the trajectory drops out of the vital zone (in yards).
    public let maxPBRYards: Int

    /// The sight-in elevation offset at 100 yards (in hundredths of an inch, e.g. 250 = +2.5 inches).
    public let sightInAt100Yards: Int

    public init(
        nearZeroYards: Int,
        farZeroYards: Int,
        minPBRYards: Int,
        maxPBRYards: Int,
        sightInAt100Yards: Int
    ) {
        self.nearZeroYards = nearZeroYards
        self.farZeroYards = farZeroYards
        self.minPBRYards = minPBRYards
        self.maxPBRYards = maxPBRYards
        self.sightInAt100Yards = sightInAt100Yards
    }

    /**
     Solves the Point Blank Range (PBR) for a given vital zone target size.
     */
    public static func solve(
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        initialVelocity: Measurement<UnitSpeed>,
        sightHeight: Measurement<UnitLength>,
        vitalSize: Measurement<UnitLength>
    ) -> Result<PBR, Error> {
        let initialVelocityFPS = initialVelocity.converted(to: .feetPerSecond).value
        let sightHeightInches = sightHeight.converted(to: .inches).value
        let vitalSizeInches = vitalSize.converted(to: .inches).value

        return solve(
            dragFunction: dragFunction,
            dragCoefficient: dragCoefficient,
            initialVelocity: initialVelocityFPS,
            sightHeight: sightHeightInches,
            vitalSize: vitalSizeInches
        )
    }

    /**
     Solves the Point Blank Range (PBR) using raw imperial values (fps, inches).
     */
    public static func solve(
        dragFunction: DragFunction = .g1,
        dragCoefficient: Double,
        initialVelocity: Double,
        sightHeight: Double,
        vitalSize: Double
    ) -> Result<PBR, Error> {
        guard dragCoefficient > 0, initialVelocity > 0, vitalSize > 0 else {
            return .failure(NSError(domain: "PBRComputation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid ballistic input parameters"]))
        }

        let targetApexInches = vitalSize / 2.0
        let targetApexFeet = targetApexInches / 12.0
        let vitalBottomFeet = -(vitalSize / 2.0) / 12.0
        let initialY = -sightHeight / 12.0

        // Find the maximum apex height for a given elevation angle
        func getApex(angleDeg: Double) -> Double {
            let angleRad = Math.degToRad(angleDeg)
            var vx = initialVelocity * cos(angleRad)
            var vy = initialVelocity * sin(angleRad)
            var y = initialY
            let gx = Constants.GRAVITY * sin(angleRad)
            let gy = Constants.GRAVITY * cos(angleRad)

            var maxApex = y
            while vy > 0 {
                let v = sqrt(vx * vx + vy * vy)
                let dt = 0.5 / max(v, 1e-9)
                let dv = Drag.retard(dragFunction: dragFunction, dragCoefficient: dragCoefficient, projectileVelocity: v)
                let dvx = -(vx / max(v, 1e-9)) * dv
                let dvy = -(vy / max(v, 1e-9)) * dv

                let vxNext = vx + dt * dvx + dt * gx
                let vyNext = vy + dt * dvy + dt * gy

                let yNext = y + dt * (vy + vyNext) / 2.0

                if yNext > maxApex {
                    maxApex = yNext
                }

                vx = vxNext
                vy = vyNext
                y = yNext
            }

            return maxApex
        }

        // Bisection to find elevation angle producing target apex height
        var lowAngle = 0.0
        var highAngle = 2.0 // 120 MOA

        for _ in 0..<35 {
            let mid = (lowAngle + highAngle) / 2.0
            if getApex(angleDeg: mid) < targetApexFeet {
                lowAngle = mid
            } else {
                highAngle = mid
            }
        }

        let optimalAngle = (lowAngle + highAngle) / 2.0
        let optAngleRad = Math.degToRad(optimalAngle)
        let gx = Constants.GRAVITY * sin(optAngleRad)
        let gy = Constants.GRAVITY * cos(optAngleRad)

        var vx = initialVelocity * cos(optAngleRad)
        var vy = initialVelocity * sin(optAngleRad)
        var x: Double = 0
        var y: Double = initialY

        var nearZero: Double = 0
        var farZero: Double = 0
        var minPBR: Double = (initialY >= vitalBottomFeet) ? 0 : -1
        var maxPBR: Double = 0
        var tin100: Int = 0
        var passed100 = false
        var passedApex = false

        let maxFeet = 15000.0 // 5000 yards

        while x <= maxFeet {
            let v = sqrt(vx * vx + vy * vy)
            let dt = 0.5 / max(v, 1e-9)
            let dv = Drag.retard(dragFunction: dragFunction, dragCoefficient: dragCoefficient, projectileVelocity: v)
            let dvx = -(vx / max(v, 1e-9)) * dv
            let dvy = -(vy / max(v, 1e-9)) * dv

            let vxNext = vx + dt * dvx + dt * gx
            let vyNext = vy + dt * dvy + dt * gy

            let xNext = x + dt * (vx + vxNext) / 2.0
            let yNext = y + dt * (vy + vyNext) / 2.0

            if vyNext <= 0 {
                passedApex = true
            }

            // Near zero (crossing y=0 on the way up)
            if nearZero == 0 && !passedApex && y <= 0 && yNext >= 0 {
                let dy = yNext - y
                let alpha = abs(dy) > 1e-12 ? (0 - y) / dy : 0.5
                nearZero = x + alpha * (xNext - x)
            }

            // Min PBR (entering vital zone on the way up)
            if minPBR < 0 && y <= vitalBottomFeet && yNext >= vitalBottomFeet {
                let dy = yNext - y
                let alpha = abs(dy) > 1e-12 ? (vitalBottomFeet - y) / dy : 0.5
                minPBR = x + alpha * (xNext - x)
            }

            // 100 yards (300 ft) elevation
            if !passed100 && xNext >= 300.0 {
                let dx = xNext - x
                let alpha = abs(dx) > 1e-12 ? (300.0 - x) / dx : 0.5
                let yAt100 = y + alpha * (yNext - y)
                tin100 = Int((yAt100 * 12.0 * 100.0).rounded())
                passed100 = true
            }

            // Far zero (crossing y=0 on the way down)
            if farZero == 0 && passedApex && y >= 0 && yNext <= 0 {
                let dy = yNext - y
                let alpha = abs(dy) > 1e-12 ? (0 - y) / dy : 0.5
                farZero = x + alpha * (xNext - x)
            }

            // Max PBR (crossing below vitalBottomFeet on the way down)
            if maxPBR == 0 && passedApex && y >= vitalBottomFeet && yNext <= vitalBottomFeet {
                let dy = yNext - y
                let alpha = abs(dy) > 1e-12 ? (vitalBottomFeet - y) / dy : 0.5
                maxPBR = x + alpha * (xNext - x)
                break
            }

            x = xNext
            y = yNext
            vx = vxNext
            vy = vyNext
        }

        let result = PBR(
            nearZeroYards: Int((nearZero / 3.0).rounded()),
            farZeroYards: Int((farZero / 3.0).rounded()),
            minPBRYards: Int((max(0, minPBR) / 3.0).rounded()),
            maxPBRYards: Int((maxPBR / 3.0).rounded()),
            sightInAt100Yards: tin100
        )

        return .success(result)
    }
}
