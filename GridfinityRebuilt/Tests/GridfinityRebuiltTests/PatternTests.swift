import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct PatternTests {
    @Test func `patternLinear matches OpenSCAD`() async throws {
        let cell = Box([2, 3, 4]).translated(x: 1, y: 2)
        let actual = try await measure(patternLinear(x: 3, y: 2, spacingX: 10, spacingY: 7, cell))
        let problems = compare(actual, try ReferenceSet.containing().metrics("pattern_linear"), volumeTolerance: 1e-9, boundsTolerance: 1e-6)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `spacingY defaults to spacingX`() async throws {
        let cell = Box([1, 1, 1])
        let a = try await measure(patternLinear(x: 2, y: 2, spacingX: 5, cell))
        let b = try await measure(patternLinear(x: 2, y: 2, spacingX: 5, spacingY: 5, cell))
        #expect(a.min.y == b.min.y && a.max.y == b.max.y)
    }
}
