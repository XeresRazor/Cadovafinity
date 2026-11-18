import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct ProfilesTests {
    let d = Dimensions.standard
    let dh = 16.0

    @Test func `rounded rectangle matches OpenSCAD`() async throws {
        let actual = try await measure(roundedRectangle(length: 40, width: 20, height: 7, radius: 4))
        let problems = compare(actual, try ReferenceSet.containing().metrics("rounded_rectangle"), volumeTolerance: 0.01, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `base profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.baseProfile().extruded(height: 10))
        let problems = compare(actual, try ReferenceSet.containing().metrics("profile_base"), volumeTolerance: 0.01, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `wall profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.wallProfile(height: dh).extruded(height: 10))
        let problems = compare(actual, try ReferenceSet.containing().metrics("profile_wall"), volumeTolerance: 1e-4, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `wall profile at dWall 1.6 matches OpenSCAD`() async throws {
        var wide = Dimensions.standard
        wide.dWall = 1.6
        let actual = try await measure(wide.wallProfile(height: dh).extruded(height: 10))
        let problems = compare(actual, try ReferenceSet.containing().metrics("profile_wall_dw16"), volumeTolerance: 1e-4, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `lipless wall profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.lipelessWallProfile(height: dh).extruded(height: 10))
        let problems = compare(actual, try ReferenceSet.containing().metrics("profile_wall2"), volumeTolerance: 0.01, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }
}
