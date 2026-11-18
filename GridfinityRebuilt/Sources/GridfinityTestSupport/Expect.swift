// GridfinityTestSupport is for test targets only: it imports Testing, so add it
// only to `.testTarget` dependencies, never to a library or executable target.
import Testing
import Cadova

/// Compares `geometry` with the named reference case.
///
/// When `references` is nil, the reference set is resolved from the caller's file
/// (`sourceLocation.filePath`), not from a default argument. A nested default such as
/// `.containing()` could evaluate `#filePath` inside this support target and silently
/// pick the wrong package's Reference folder when another package calls this function.

public func expectMatchesReference(
    _ name: String, _ geometry: any Geometry3D,
    references: ReferenceSet? = nil,
    volumeTolerance: Double = 1e-4, boundsTolerance: Double = 0.05,
    symmetricDifferenceTolerance: Double? = defaultSymmetricDifferenceTolerance,
    segments: Int = 64,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let references = references ?? ReferenceSet.containing(file: sourceLocation.filePath)
    let actual = try await measure(geometry, segments: segments)
    let expected = try references.metrics(name)
    for problem in compare(actual, expected, volumeTolerance: volumeTolerance, boundsTolerance: boundsTolerance) {
        Issue.record(Comment(rawValue: "\(name): \(problem)"), sourceLocation: sourceLocation)
    }
    if let limit = symmetricDifferenceTolerance {
        let v = try await symmetricDifferenceVolume(geometry, against: references.stlURL(name), segments: segments)
        #expect(v <= limit, "\(name): symmetric difference \(v) mm^3 exceeds \(limit)", sourceLocation: sourceLocation)
    }
}
