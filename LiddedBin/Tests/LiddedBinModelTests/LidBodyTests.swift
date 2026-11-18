import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct LidBodyTests {
    let refs = ReferenceSet.containing()

    @Test func `2x2x3 lid without grips`() async throws {
        let d = design { $0.lipGrips = .none }
        try await expectMatchesReference("lid_2x2x3_nogrips", lidOnBed(d), references: refs)
    }

    @Test func `2x2x3 lid with default grips`() async throws {
        try await expectMatchesReference("lid_2x2x3_xy", lidOnBed(design()), references: refs)
    }

    @Test func `1x1x2 lid`() async throws {
        let d = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2 }
        try await expectMatchesReference("lid_1x1x2_nogrips", lidOnBed(d), references: refs)
    }

    @Test func `2x3x3 lid with Y grips opening upward`() async throws {
        let d = design { $0.lipGrips = .y; $0.gridX = 2; $0.gridY = 3; $0.lidOrientation = .up }
        try await expectMatchesReference("lid_2x3x3_grips_y_up", lidOnBed(d), references: refs)
    }
}
