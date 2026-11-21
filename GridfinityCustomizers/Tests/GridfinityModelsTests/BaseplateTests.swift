import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import GridfinityModels

/// Whole baseplates against gridfinity-rebuilt-baseplate.scad run with `-D` defines. Each
/// configuration equals the case's effective defines: the file's defaults (`enable_magnet =
/// true`, `style_hole = 2`, `d_screw = 3.35`, `n_screws = 1`, no drawer) apply where a case
/// does not set them, and they are also `BaseplateConfiguration`'s defaults.
struct BaseplateTests {
    let refs = ReferenceSet.containing()

    static func plate(
        _ x: Int, _ y: Int, _ style: PlateStyle,
        magnets: Bool = true, holes: ScrewHoleStyle = .counterbore,
        configure: (inout BaseplateConfiguration) -> Void = { _ in }
    ) -> BaseplateConfiguration {
        var c = BaseplateConfiguration()
        c.gridX = x
        c.gridY = y
        c.plateStyle = style
        c.magnetHoles = magnets
        c.screwHoles = holes
        configure(&c)
        return c
    }

    func expectPlate(
        _ name: String, _ configuration: BaseplateConfiguration,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await expectMatchesReference(
            name, BaseplateDesign(configuration).geometry(), references: refs, sourceLocation: sourceLocation
        )
    }

    @Test func `thin 2x2 plate matches OpenSCAD`() async throws {
        try await expectPlate("thin_2x2", Self.plate(2, 2, .thin))
    }

    @Test func `weighted 2x2 plate matches OpenSCAD`() async throws {
        try await expectPlate("weighted_2x2", Self.plate(2, 2, .weighted))
    }

    @Test func `skeletonized 2x2 plate matches OpenSCAD`() async throws {
        try await expectPlate("skeleton_2x2", Self.plate(2, 2, .skeletonized))
    }

    @Test func `skeletonized plate with countersinks and no magnets matches OpenSCAD`() async throws {
        try await expectPlate(
            "skeleton_countersink_nomagnet", Self.plate(2, 1, .skeletonized, magnets: false, holes: .countersink)
        )
    }

    @Test func `skeletonized plate without holes matches OpenSCAD`() async throws {
        try await expectPlate("skeleton_noholes_nomagnet", Self.plate(1, 1, .skeletonized, magnets: false, holes: .none))
    }

    @Test func `screw-together 2x3 plate with two screws matches OpenSCAD`() async throws {
        try await expectPlate("screw_together_2x3", Self.plate(2, 3, .screwTogether) { $0.screwsPerCell = 2 })
    }

    @Test func `minimal screw-together 2x2 plate matches OpenSCAD`() async throws {
        try await expectPlate("screw_together_minimal_2x2", Self.plate(2, 2, .screwTogetherMinimal))
    }

    @Test func `plate filling a drawer along X matches OpenSCAD`() async throws {
        try await expectPlate("fit_x_drawer", Self.plate(0, 2, .thin) {
            $0.drawerX = 150
            $0.fitX = 0.5
        })
    }

    @Test func `plate filling a drawer on both axes matches OpenSCAD`() async throws {
        try await expectPlate("fit_both_drawer", Self.plate(0, 0, .weighted) {
            $0.drawerX = 130
            $0.drawerY = 95
            $0.fitX = -1
            $0.fitY = 1
        })
    }

    @Test func `weighted plate without magnets or screw holes matches OpenSCAD`() async throws {
        try await expectPlate("weighted_magnet_off", Self.plate(2, 2, .weighted, magnets: false, holes: .none))
    }

    @Test func `floor depth follows calculate_off`() {
        func depth(_ style: PlateStyle, magnets: Bool = true, holes: ScrewHoleStyle = .counterbore) -> Double {
            BaseplateDesign(Self.plate(1, 1, style, magnets: magnets, holes: holes)).floorDepth
        }
        #expect(depth(.thin) == 0)
        #expect(depth(.weighted) == 6.4)
        #expect(abs(depth(.skeletonized) - (1 + 2.4 + 3)) < 1e-12)
        #expect(abs(depth(.skeletonized, magnets: false, holes: .countersink) - (1 + 2.5)) < 1e-12)
        // Q11: without screw holes the skeleton floor adds the screw diameter.
        #expect(abs(depth(.skeletonized, magnets: false, holes: .none) - (1 + 3.35)) < 1e-12)
        #expect(depth(.screwTogether) == 6.75)
        #expect(depth(.screwTogetherMinimal, magnets: false, holes: .none) == 6.75)
    }

    @Test func `a zero grid count fills the drawer with whole cells`() {
        let design = BaseplateDesign(Self.plate(0, 2, .thin) {
            $0.drawerX = 150
            $0.fitX = 0.5
        })
        #expect(design.cellsX == 3)
        #expect(design.cellsY == 2)
        #expect(design.width == 150)
        #expect(design.depth == 83.5)
        #expect(abs(design.offsetX - 6.125) < 1e-12)
        #expect(design.offsetY == 0)
    }

    @Test(arguments: PlateStyle.allCases)
    func `the plate spans from minus the floor depth to 4.4`(style: PlateStyle) async throws {
        let design = BaseplateDesign(Self.plate(1, 1, style))
        let metrics = try await measure(design.geometry())
        #expect(abs(metrics.max.z - 4.4) < 1e-9)
        #expect(abs(metrics.min.z + design.floorDepth) < 1e-9)
    }
}
