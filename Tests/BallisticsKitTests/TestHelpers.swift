
import Foundation

extension Double {
    func isApproximatelyEqual(to other: Double, absoluteTolerance: Double) -> Bool {
        return abs(self - other) <= absoluteTolerance
    }
}
