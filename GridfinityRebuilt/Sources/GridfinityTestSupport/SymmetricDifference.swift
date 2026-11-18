import Foundation
import Cadova

/// Volume of `(A minus B) plus (B minus A)` between `geometry` and the STL at `stl`.
public func symmetricDifferenceVolume(
    _ geometry: any Geometry3D, against stl: URL, segments: Int = 64
) async throws -> Double {
    guard FileManager.default.fileExists(atPath: stl.path) else {
        throw ReferenceError.missingSTL(stl.path)
    }
    let mine = geometry.withSegmentation(count: segments)
    let theirs = Import(model: stl)
    let difference = Union {
        mine.subtracting { theirs }
        theirs.subtracting { mine }
    }
    return try await ModelFileGenerator.evaluate { evaluator in
        await evaluator.measurements(of: difference).volume
    }
}

/// Default symmetric-difference limit in mm^3.
///
/// Measured tessellation noise (OpenSCAD STL vs Cadova, 64 segments, cornerSegments 16 for
/// wall/shell cases) on existing cases ranges from 7e-8 to 1.2e-5 mm^3. The smallest defect
/// that must be caught, the `rFo3 / 2 -> rFo3` mutation in BlockBase, produced 0.737 mm^3.
/// 0.05 sits between them: about 4,000x the worst noise and about 15x below that defect.
/// Larger parts have more tessellation noise, so a test may override
/// `symmetricDifferenceTolerance:` with about 10x its own measured noise, but never above the
/// smallest defect it needs to catch.
public let defaultSymmetricDifferenceTolerance: Double = 0.05
