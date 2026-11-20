import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct BinBodyTests {
    let refs = ReferenceSet.containing()

    @Test func `2x2x3 bin without grips`() async throws {
        let design = design { $0.lipGrips = .none }
        try await expectMatchesReference("bin_2x2x3_nogrips", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `2x2x3 bin with default grips`() async throws {
        let design = design()
        try await expectMatchesReference("bin_2x2x3_xy", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `1x1x2 bin with two compartments`() async throws {
        let design = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 2; $0.divY = 1 }
        try await expectMatchesReference("bin_1x1x2_nogrips_div2", design.binSolid(pockets: design.pockets()), references: refs)
    }

    /// Tests the hollow cut used by the bin slice (and by direct API use with a count of 0), which
    /// the customizer does not offer. Deliberate deviation from OpenSCAD: its empty `children()`
    /// quirk leaves the bin solid (21418.9 mm^3), but the port cuts the whole interior. The
    /// reference is generated from a patched copy of lid-bin.scad (see Reference/generate.py,
    /// HOLLOW_PATCH).
    @Test func `the hollow cut of the bin slice, deliberately unlike OpenSCAD`() async throws {
        let design = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 0; $0.divY = 0 }
        #expect(design.pockets() == nil)
        try await expectMatchesReference("bin_1x1x2_nogrips_div0", design.binSolid(pockets: nil), references: refs)
    }

    @Test func `hollow cut has less volume than the same bin with two compartments`() async throws {
        let hollow = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 0; $0.divY = 1 }
        let divided = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 2; $0.divY = 1 }
        let hollowVolume = try await measure(hollow.binSolid(pockets: hollow.pockets())).volume
        let dividedVolume = try await measure(divided.binSolid(pockets: divided.pockets())).volume
        #expect(hollowVolume < dividedVolume)
    }

    @Test func `3x2x3 bin with X grips`() async throws {
        let design = design { $0.lipGrips = .x; $0.gridX = 3; $0.gridY = 2; $0.divX = 3; $0.divY = 2 }
        try await expectMatchesReference("bin_3x2x3_grips_x", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `partially raised interior`() async throws {
        let design = design { $0.lipGrips = .none; $0.interiorStyle = .partialRaised; $0.divX = 2; $0.divY = 2 }
        try await expectMatchesReference("bin_2x2x3_partial_raised", design.binSolid(pockets: design.pockets()), references: refs)
    }
}
