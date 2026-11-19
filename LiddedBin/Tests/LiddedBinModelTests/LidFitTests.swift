import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// Behavior of the lid fit controls. There is no OpenSCAD reference for these, so they are
/// measured with ray casts on the closed assembly.
///
/// The lid clearance is the side gap between the vertical plate edge and the slot face. The tongue
/// above the plate has a 45 degree chamfer facing the slot roof; its offset is derived from the
/// clearance (`min(0.30, clearance + 0.10)`).
struct LidFitTests {
    /// The y positions of the slot face (the bin's first entry along +y, since the slot is empty
    /// before it) and of the lid edge (the lid's last exit) for a ray along +y at x = 0.
    func faces(_ design: LiddedBinDesign, z: Double) async throws -> (slot: Double, edge: Double) {
        let origin = Vector3D(0, 0, z)
        return try await ModelFileGenerator.evaluate { evaluator in
            let bin = await evaluator.surfaces(of: design.binSolid(pockets: design.pockets()),
                                               from: origin, in: .positiveY)
            let lid = await evaluator.surfaces(of: design.lidBody(), from: origin, in: .positiveY)
            return (bin.first { $0.transition == .entering }?.position.y ?? .nan,
                    lid.last { $0.transition == .exiting }?.position.y ?? .nan)
        }
    }

    func plateTop(_ design: LiddedBinDesign) -> Double {
        design.storageHeight + design.d.hBase - design.fit.vPosTolerance
    }

    /// Gap between the vertical plate edge and the slot face, at mid plate thickness.
    func plateGap(_ design: LiddedBinDesign) async throws -> Double {
        let f = try await faces(design, z: plateTop(design) - design.fit.thickness / 2)
        return f.slot - f.edge
    }

    /// Perpendicular gap between the tongue chamfer and the slot roof, both 45 degree slopes,
    /// from a ray 0.45 mm above the plate top (about mid tongue height).
    func chamferGap(_ design: LiddedBinDesign) async throws -> Double {
        let f = try await faces(design, z: plateTop(design) + 0.45)
        return (f.slot - f.edge) / 2.0.squareRoot()
    }

    /// Volume where the closed lid and the bin overlap.
    func interference(_ design: LiddedBinDesign) async throws -> Double {
        try await measure(design.binSolid(pockets: design.pockets()).intersecting { design.lidBody() }).volume
    }

    @Test func `original fit leaves a 0_45 mm gap at the plate edge`() async throws {
        let d = design()
        let f = try await faces(d, z: plateTop(d) - d.fit.thickness / 2)
        #expect(abs(f.slot - 40.55) < 0.02, "slot \(f.slot)")
        #expect(abs(f.edge - 40.10) < 0.02, "edge \(f.edge)")
        #expect(abs(f.slot - f.edge - 0.45) < 0.02)
    }

    @Test(arguments: [0.45, 0.20, 0.10, 0.05])
    func `plate edge gap equals the lid clearance`(clearance: Double) async throws {
        let gap = try await plateGap(design { $0.lidClearance = clearance })
        print("plate gap \(clearance): \(gap)")
        #expect(abs(gap - clearance) < 0.01, "clearance \(clearance) gap \(gap)")
    }

    @Test(arguments: [(0.45, 0.229), (0.20, 0.229), (0.10, 0.129), (0.05, 0.079)])
    func `chamfer gap follows the derived tongue offset`(clearance: Double, expected: Double) async throws {
        let gap = try await chamferGap(design { $0.lidClearance = clearance })
        print("chamfer gap \(clearance): \(gap)")
        #expect(abs(gap - expected) < 0.02, "clearance \(clearance) gap \(gap)")
    }

    @Test func `lid clearance does not move the slot`() async throws {
        let a = design(), b = design { $0.lidClearance = 0.10 }
        for z in [plateTop(a) - 0.45, plateTop(a) + 0.45] {
            let fa = try await faces(a, z: z), fb = try await faces(b, z: z)
            #expect(abs(fa.slot - fb.slot) < 1e-6)
        }
    }

    @Test func `the default lid clearance still fits`() async throws {
        let original = try await interference(design())
        #expect(abs(original - 1.392) < 0.01)
        let volume = try await interference(design { $0.lidClearance = 0.20 })
        print("lid/bin interference, clearance 0.20: \(volume) mm^3")
        #expect(volume < 8)
        for c in [0.10, 0.05] {
            print("lid/bin interference, clearance \(c): \(try await interference(design { $0.lidClearance = c })) mm^3")
        }
    }

    @Test func `default design derives the tongue offset from the clearance`() {
        #expect(LiddedBinConfiguration().lidClearance == 0.20)
        #expect(LiddedBinDesign(LiddedBinConfiguration()).fit.lipClearance == 0.30)
        #expect(LiddedBinDesign(.openSCADOriginal).fit.lipClearance == 0.30)
        var c = LiddedBinConfiguration()
        c.lidClearance = 0.10
        #expect(abs(LiddedBinDesign(c).fit.lipClearance - 0.20) < 1e-9)
    }

    @Test func `default side clearance reproduces the original inset`() {
        #expect(abs(LidFit().sideClearance - 0.45) < 1e-9)
        #expect(abs(LidFit().plateInset - 3.8) < 1e-9)
        var f = LidFit()
        f.hFitTolerance = 1.3; f.wallThickness = 1.0
        #expect(abs(f.sideClearance - 0.95) < 1e-9)
        #expect(abs(f.plateInset - (0.5 + 1.3 * 3)) < 1e-9)
    }
}
