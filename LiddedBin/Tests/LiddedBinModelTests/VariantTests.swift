import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct VariantTests {
    let refs = ReferenceSet.containing()

    private func checkBin(_ name: String, _ d: LiddedBinDesign) async throws {
        try await expectMatchesReference(name, d.binSolid(pockets: d.pockets()), references: refs)
    }

    // Lid orientation
    @Test func `2x2x3 bin lid left`() async throws {
        try await checkBin("bin_2x2x3_left", design { $0.lidOrientation = .left; $0.divX = 2; $0.divY = 2 })
    }
    @Test func `2x2x3 bin lid right`() async throws {
        try await checkBin("bin_2x2x3_right", design { $0.lidOrientation = .right; $0.divX = 2; $0.divY = 2 })
    }
    @Test func `2x2x3 bin lid up`() async throws {
        try await checkBin("bin_2x2x3_up", design { $0.lidOrientation = .up; $0.divX = 2; $0.divY = 2 })
    }
    @Test func `2x2x3 bin lid down`() async throws {
        try await checkBin("bin_2x2x3_down", design { $0.lidOrientation = .down; $0.divX = 2; $0.divY = 2 })
    }
    @Test func `2x2x3 lid opening right`() async throws {
        let d = design { $0.lidOrientation = .right }
        try await expectMatchesReference("lid_2x2x3_right", lidOnBed(d), references: refs)
    }
    @Test func `2x2x3 lid opening down`() async throws {
        let d = design { $0.lidOrientation = .down }
        try await expectMatchesReference("lid_2x2x3_down", lidOnBed(d), references: refs)
    }

    // Height modes
    @Test func `2x2 bin with 20 mm internal height snapped`() async throws {
        try await checkBin("bin_2x2_internal_20_snap", design {
            $0.heightMode = .internalMillimeters; $0.gridZ = 20; $0.snapHeight = true; $0.divX = 2; $0.divY = 2
        })
    }
    @Test func `2x2 bin with 30 mm external height`() async throws {
        try await checkBin("bin_2x2_external_30", design {
            $0.heightMode = .externalMillimeters; $0.gridZ = 30; $0.snapHeight = false; $0.divX = 2; $0.divY = 2
        })
    }
    @Test func `2x2x3 bin with internal height override`() async throws {
        try await checkBin("bin_2x2x3_height_internal", design { $0.internalHeightOverride = 20; $0.divX = 2; $0.divY = 2 })
    }

    // Compartment patterns and grips
    @Test func `3x2x3 multisize bin`() async throws {
        try await checkBin("bin_3x2x3_multisize", design {
            $0.compartmentPattern = .multiSize; $0.gridX = 3; $0.gridY = 2; $0.divX = 3; $0.divY = 2
            $0.divMultiple = 2; $0.lipGrips = .none
        })
    }
    @Test func `3x2x3 bin with Y grips`() async throws {
        try await checkBin("bin_3x2x3_grips_y", design {
            $0.lipGrips = .y; $0.gridX = 3; $0.gridY = 2; $0.divX = 3; $0.divY = 2
        })
    }
    @Test func `multisize with divX 1`() async throws {
        try await checkBin("bin_2x2x3_multisize_divx1", design {
            $0.compartmentPattern = .multiSize; $0.divX = 1; $0.divY = 2; $0.lipGrips = .none
        })
    }
    @Test func `multisize with divY 0`() async throws {
        try await checkBin("bin_2x2x3_multisize_divy0", design {
            $0.compartmentPattern = .multiSize; $0.divX = 2; $0.divY = 0; $0.lipGrips = .none
        })
    }

    // Fit constants away from their defaults
    private var sweepFit: LidFit {
        var f = LidFit()
        f.hFitTolerance = 1.3; f.vFitTolerance = 0.05; f.vPosTolerance = 0.3
        f.wallThickness = 1.0; f.thickness = 1.1
        return f
    }
    private func sweepDesign() -> LiddedBinDesign {
        var c = LiddedBinConfiguration.openSCADOriginal
        c.cornerSegments = 16; c.divX = 2; c.divY = 2; c.lipGrips = .none
        return LiddedBinDesign(c, fit: sweepFit)
    }
    @Test func `2x2x3 bin with swept fit constants`() async throws {
        try await checkBin("bin_2x2x3_fit_sweep", sweepDesign())
    }
    @Test func `2x2x3 lid with swept fit constants`() async throws {
        try await expectMatchesReference("lid_2x2x3_fit_sweep", lidOnBed(sweepDesign()), references: refs)
    }
}
