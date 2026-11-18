import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct BlockTests {
    let refs = ReferenceSet.containing()
    let d = Dimensions.standard

    @Test func `corner segments option reproduces OpenSCAD tessellation without test-level workarounds`() async throws {
        let wall = d.blockWall(
            gridX: 2, gridY: 1,
            profile: d.wallProfile(height: 16),
            cornerSegments: 16
        )
        // Ambient segmentation stays at 64 (measure applies it); only corners use 16.
        try await expectMatchesReference("block_wall_2x1", wall, references: refs, volumeTolerance: 1e-4)
    }

    @Test func `nil corner segments is unchanged`() async throws {
        let a = try await measure(d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16)))
        let b = try await measure(d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16), cornerSegments: nil))
        #expect(abs(a.volume - b.volume) < 1e-9)
    }

    @Test func `block base solid matches OpenSCAD`() async throws {
        try await expectMatchesReference("block_base_solid", d.blockBaseSolid(), references: refs, volumeTolerance: 1e-4)
    }

    @Test func `block base solid with negative offset matches OpenSCAD`() async throws {
        try await expectMatchesReference("block_base_solid_offset", d.blockBaseSolid(offset: -1.5), references: refs, volumeTolerance: 1e-4)
    }

    @Test func `block wall 2x1 matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "block_wall_2x1",
            d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16), cornerSegments: 16),
            references: refs, volumeTolerance: 1e-4
        )
    }

    /// Swapped X/Y would give the 2x1 bounds, so this pins the orientation.
    @Test func `block wall 1x2 matches OpenSCAD`() async throws {
        let actual = try await measure(
            d.blockWall(gridX: 1, gridY: 2, profile: d.wallProfile(height: 16), cornerSegments: 16)
        )
        let problems = compare(actual, try refs.metrics("block_wall_1x2"), volumeTolerance: 1e-4, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `lipless block wall 1x1 matches OpenSCAD`() async throws {
        let actual = try await measure(
            d.blockWall(gridX: 1, gridY: 1, profile: d.lipelessWallProfile(height: 16), cornerSegments: 16)
        )
        let problems = compare(actual, try refs.metrics("block_wall_lipless_1x1"), volumeTolerance: 1e-4, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `block bottom 2x1 at dWall 1.6 matches OpenSCAD`() async throws {
        var wide = Dimensions.standard
        wide.dWall = 1.6
        let actual = try await measure(wide.blockBottom(height: 15.9, gridX: 2, gridY: 1))
        let problems = compare(actual, try refs.metrics("block_bottom_2x1_dw16"), volumeTolerance: 1e-4, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `block bottom 2x1 matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "block_bottom_2x1",
            d.blockBottom(height: 15.9, gridX: 2, gridY: 1),
            references: refs, volumeTolerance: 1e-4
        )
    }
}
