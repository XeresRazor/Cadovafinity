import Testing
import Cadova
import GridfinityTestSupport

struct MeasureTests {
    @Test func `measure matches the reference harness for a cube`() async throws {
        let actual = try await measure(Box([2, 3, 4]))
        let expected = try ReferenceSet.containing().metrics("unit_cube")
        let problems = compare(actual, expected, volumeTolerance: 0.01, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }
}
