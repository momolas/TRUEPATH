//
//  DangerSpace.swift
//  swift-ballistics
//
//  Created by Raymond Dowe on 26/11/2024.
//

import Foundation

/// Represents the danger space (range error tolerance window) for a given target size and distance.
public struct DangerSpace: Sendable, Equatable, Hashable {

    /// The closest distance where the bullet enters the target vertical silhouette.
    public let nearBound: Measurement<UnitLength>

    /// The farthest distance before the bullet falls below the target vertical silhouette.
    public let farBound: Measurement<UnitLength>

    /// The total depth of the danger space window (`farBound - nearBound`).
    public var totalDepth: Measurement<UnitLength> {
        let diff = max(0, farBound.converted(to: .meters).value - nearBound.converted(to: .meters).value)
        return Measurement(value: diff, unit: .meters)
    }

    public init(
        nearBound: Measurement<UnitLength>,
        farBound: Measurement<UnitLength>
    ) {
        self.nearBound = nearBound
        self.farBound = farBound
    }

    /**
     Calculates the danger space for a target of specified vertical height at a given distance.

     The danger space defines the range interval $[D_{\min}, D_{\max}]$ where the projectile's trajectory
     remains within the top and bottom boundaries of the target when aimed at center.

     - Parameters:
       - solution: The computed trajectory solution.
       - targetDistance: The nominal distance to the target.
       - targetHeight: The vertical height of the target.

     - Returns:
       A `DangerSpace` containing the near bound, far bound, and depth window.
     */
    public static func calculate(
        solution: Ballistics,
        targetDistance: Measurement<UnitLength>,
        targetHeight: Measurement<UnitLength>
    ) -> DangerSpace {
        guard let centerPoint = solution.getPoint(at: targetDistance), !solution.distances.isEmpty else {
            return DangerSpace(nearBound: targetDistance, farBound: targetDistance)
        }

        let centerDropInches = centerPoint.drop.converted(to: .inches).value
        let halfHeightInches = targetHeight.converted(to: .inches).value / 2.0

        let topBoundInches = centerDropInches + halfHeightInches
        let bottomBoundInches = centerDropInches - halfHeightInches

        let targetDistMeters = targetDistance.converted(to: .meters).value

        // Search backward from target distance for near bound (crossing topBound)
        var nearDistMeters = targetDistMeters
        var currentDist = targetDistMeters
        while currentDist > 0 {
            currentDist = max(0, currentDist - 1.0)
            if let p = solution.getPoint(at: Measurement(value: currentDist, unit: .meters)) {
                let drop = p.drop.converted(to: .inches).value
                if drop <= topBoundInches {
                    nearDistMeters = currentDist
                } else {
                    break
                }
            }
        }

        // Search forward from target distance for far bound (crossing bottomBound)
        var farDistMeters = targetDistMeters
        currentDist = targetDistMeters
        let maxSearchMeters = targetDistMeters + 2000.0
        while currentDist < maxSearchMeters {
            currentDist += 1.0
            if let p = solution.getPoint(at: Measurement(value: currentDist, unit: .meters)) {
                let drop = p.drop.converted(to: .inches).value
                if drop >= bottomBoundInches {
                    farDistMeters = currentDist
                } else {
                    break
                }
            } else {
                break
            }
        }

        return DangerSpace(
            nearBound: Measurement(value: nearDistMeters, unit: .meters),
            farBound: Measurement(value: farDistMeters, unit: .meters)
        )
    }
}
