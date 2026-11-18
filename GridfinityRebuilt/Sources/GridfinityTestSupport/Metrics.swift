import Foundation
import Cadova

public struct Metrics: Sendable {
    public var volume: Double
    public var min: Vector3D
    public var max: Vector3D
    public init(volume: Double, min: Vector3D, max: Vector3D) {
        self.volume = volume; self.min = min; self.max = max
    }
}

/// Measures volume and bounding box. `segments` is the segment count per full circle and
/// must equal FN in Reference/generate.py.
public func measure(_ geometry: any Geometry3D, segments: Int = 64) async throws -> Metrics {
    let g = geometry.withSegmentation(count: segments)
    return try await ModelFileGenerator.evaluate { evaluator in
        let bounds = await evaluator.bounds(of: g)
        let volume = await evaluator.measurements(of: g).volume
        return Metrics(volume: volume, min: bounds?.minimum ?? .zero, max: bounds?.maximum ?? .zero)
    }
}

/// Returns a list of mismatch descriptions. Empty means the metrics match.
public func compare(
    _ actual: Metrics, _ expected: Metrics,
    volumeTolerance: Double, boundsTolerance: Double
) -> [String] {
    var problems: [String] = []
    let relative = abs(actual.volume - expected.volume) / Swift.max(expected.volume, 1e-9)
    if relative > volumeTolerance {
        problems.append("volume \(actual.volume) vs reference \(expected.volume) (relative \(relative), allowed \(volumeTolerance))")
    }
    let pairs: [(String, Double, Double)] = [
        ("min.x", actual.min.x, expected.min.x), ("min.y", actual.min.y, expected.min.y),
        ("min.z", actual.min.z, expected.min.z), ("max.x", actual.max.x, expected.max.x),
        ("max.y", actual.max.y, expected.max.y), ("max.z", actual.max.z, expected.max.z),
    ]
    for (label, a, e) in pairs where abs(a - e) > boundsTolerance {
        problems.append("\(label) \(a) vs reference \(e) (allowed \(boundsTolerance))")
    }
    return problems
}
