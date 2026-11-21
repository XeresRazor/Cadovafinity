import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityModels

struct SmokeTests {
    @Test func `a box measures through the test support`() async throws {
        let metrics = try await measure(Box(1))
        #expect(abs(metrics.volume - 1) < 1e-9)
    }

    @Test func `the library reports its version`() {
        #expect(GridfinityModelsInfo.version == "0.1.0")
    }
}
