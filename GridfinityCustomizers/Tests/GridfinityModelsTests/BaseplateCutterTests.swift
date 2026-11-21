import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import GridfinityModels

struct BaseplateCutterTests {
    let refs = ReferenceSet.containing()
    let d = Dimensions.standard
    var cutters: BaseplateCutters { BaseplateCutters(d: d, b: .standard) }

    @Test func `weight pockets match OpenSCAD`() async throws {
        try await expectMatchesReference("cutter_weight", cutters.weight(), references: refs)
    }

    @Test func `skeleton profile matches OpenSCAD`() async throws {
        try await expectMatchesReference("cutter_skeleton", cutters.skeletonProfile().extruded(height: 5), references: refs)
    }

    @Test func `countersink cutter matches OpenSCAD`() async throws {
        try await expectMatchesReference("cutter_countersink", cutters.countersink(), references: refs)
    }

    @Test func `counterbore cutter matches OpenSCAD`() async throws {
        try await expectMatchesReference("cutter_counterbore", cutters.counterbore(), references: refs)
    }

    @Test func `screw-together cutter for 2x3 with two screws matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "cutter_screws_2x3_n2",
            cutters.screwTogether(
                gridX: 2, gridY: 3, offset: 6.4,
                screwDiameter: 3.35, screwHeadDiameter: 5, screwSpacing: 0.5, screwCount: 2
            ),
            references: refs
        )
    }

    @Test func `hole pattern of magnet holes matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "cutter_holes_pattern", cutters.holePattern(d.blockBaseHole(style: 1)), references: refs
        )
    }
}
