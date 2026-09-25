//
//  AcceleratedDrag.swift
//  BallisticsKit
//
//  Created by Antigravity on 20/09/2026.
//

import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// High-performance aerodynamic drag table using Apple Accelerate (`vDSP_vlintD`) for SIMD-vectorized table lookups.
/// Resamples arbitrary or Doppler radar $(Mach, C_d)$ data points onto an equidistant grid to enable $O(1)$ SIMD interpolation.
public struct AcceleratedDragTable: Sendable, Equatable {

    /// The minimum Mach number of the table grid (typically 0.0).
    public let minMach: Double

    /// The maximum Mach number of the table grid (typically 5.0).
    public let maxMach: Double

    /// The grid spacing step in Mach (e.g. 0.005).
    public let step: Double

    /// The resampled equidistant $C_d$ grid buffer.
    public let grid: [Double]

    /**
     Initializes an accelerated drag table by resampling arbitrary Mach-Cd points onto an equidistant Mach grid.

     - Parameters:
       - points: Original $(Mach, C_d)$ points.
       - minMach: Minimum Mach boundary.
       - maxMach: Maximum Mach boundary.
       - step: Equidistant grid step (default 0.005 Mach).
     */
    public init(
        points: [(mach: Double, cd: Double)],
        minMach: Double = 0.0,
        maxMach: Double = 5.0,
        step: Double = 0.005
    ) {
        precondition(!points.isEmpty, "Points array must not be empty.")
        precondition(step > 0, "Grid step must be positive.")
        precondition(maxMach > minMach, "maxMach must be greater than minMach.")

        self.minMach = minMach
        self.maxMach = maxMach
        self.step = step

        let sorted = points.sorted { $0.mach < $1.mach }
        let pointCount = Int(ceil((maxMach - minMach) / step)) + 1

        var resampled = [Double]()
        resampled.reserveCapacity(pointCount)

        for i in 0..<pointCount {
            let m = minMach + Double(i) * step
            let cd = AcceleratedDragTable.scalarInterpolate(points: sorted, mach: m)
            resampled.append(cd)
        }

        self.grid = resampled
    }

    /**
     Evaluates drag coefficients for a batch of Mach numbers simultaneously using Apple Accelerate `vDSP_vlintD`.

     - Parameter machArray: Array of Mach numbers.
     - Returns: Vectorized interpolated $C_d$ coefficients.
     */
    public func interpolate(machArray: [Double]) -> [Double] {
        guard !machArray.isEmpty else { return [] }

        let count = machArray.count
        var indices = [Double](repeating: 0, count: count)
        let maxIndex = Double(grid.count - 1)
        let invStep = 1.0 / step

        // Calculate fractional table indices
        for i in 0..<count {
            let m = machArray[i]
            let rawIdx = (m - minMach) * invStep
            indices[i] = min(maxIndex, max(0.0, rawIdx))
        }

        var results = [Double](repeating: 0, count: count)

        #if canImport(Accelerate)
        vDSP_vlintD(
            grid,
            indices,
            1,
            &results,
            1,
            vDSP_Length(count),
            vDSP_Length(grid.count)
        )
        #else
        for i in 0..<count {
            let idx = indices[i]
            let base = Int(idx)
            if base >= grid.count - 1 {
                results[i] = grid.last!
            } else {
                let frac = idx - Double(base)
                results[i] = grid[base] + frac * (grid[base + 1] - grid[base])
            }
        }
        #endif

        return results
    }

    /**
     Evaluates a single drag coefficient for a given Mach number.
     */
    public func interpolate(mach: Double) -> Double {
        let rawIdx = (mach - minMach) / step
        let maxIndex = Double(grid.count - 1)
        let clampedIdx = min(maxIndex, max(0.0, rawIdx))
        let base = Int(clampedIdx)
        if base >= grid.count - 1 {
            return grid.last!
        }
        let frac = clampedIdx - Double(base)
        return grid[base] + frac * (grid[base + 1] - grid[base])
    }

    // Helper for initial resampling
    private static func scalarInterpolate(points: [(mach: Double, cd: Double)], mach: Double) -> Double {
        if mach <= points.first!.mach { return points.first!.cd }
        if mach >= points.last!.mach { return points.last!.cd }

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            if mach >= p0.mach && mach <= p1.mach {
                let factor = (mach - p0.mach) / max(1e-9, p1.mach - p0.mach)
                return p0.cd + factor * (p1.cd - p0.cd)
            }
        }
        return points.last!.cd
    }
}

// MARK: - CustomDragModel Extension
extension CustomDragModel {

    /// Converts this CustomDragModel into an accelerated equidistant drag table.
    public func acceleratedTable(step: Double = 0.005) -> AcceleratedDragTable {
        let pairs = dataPoints.map { (mach: $0.mach, cd: $0.cd) }
        let minM = dataPoints.first?.mach ?? 0.0
        let maxM = max(5.0, dataPoints.last?.mach ?? 5.0)
        return AcceleratedDragTable(points: pairs, minMach: minM, maxMach: maxM, step: step)
    }

    /// Evaluates drag coefficients for an entire array of Mach values using Accelerate SIMD.
    public func dragCoefficients(atMachArray machs: [Double]) -> [Double] {
        let table = acceleratedTable()
        return table.interpolate(machArray: machs)
    }
}
