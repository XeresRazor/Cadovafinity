import Cadova
import Foundation

/// `pattern_circular`: `n` copies of `geometry`, rotated by `i * 360 / n` for `i` in `1...n`.
public func patternCircular(count n: Int, _ geometry: any Geometry3D) -> any Geometry3D {
    Union {
        for i in 1...max(n, 1) {
            geometry.rotated(z: Angle(degrees: Double(i) * 360 / Double(max(n, 1))))
        }
    }
}

/// `copy_mirror`: the geometry plus its mirror image across the plane normal to `axis`.
public func copyMirror(_ geometry: any Geometry3D, along axis: Axis3D = .y) -> any Geometry3D {
    Union {
        geometry
        geometry.flipped(along: [axis])
    }
}

/// `rounded_square`: a square rounded rectangle.
public func roundedSquare(length: Double, height: Double, radius: Double) -> any Geometry3D {
    roundedRectangle(length: length, width: length, height: height, radius: radius)
}

/// `clp`.
public func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { min(max(x, a), b) }
