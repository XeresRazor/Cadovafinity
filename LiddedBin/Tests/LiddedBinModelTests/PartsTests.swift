import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct PartsTests {
    let refs = ReferenceSet.containing()

    @Test func `bin slice matches OpenSCAD`() async throws {
        try await expectMatchesReference("bin_slice_2x2x3", design().geometry(for: .binSlice), references: refs)
    }

    @Test func `small bin slice with the lid up`() async throws {
        let d = design { $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.lidOrientation = .up }
        try await expectMatchesReference("bin_slice_1x1x2_up", d.geometry(for: .binSlice), references: refs)
    }

    @Test func `bin part equals the bin reference`() async throws {
        try await expectMatchesReference("bin_2x2x3_xy", design().geometry(for: .bin), references: refs)
    }

    @Test func `lid part equals the lid reference`() async throws {
        try await expectMatchesReference("lid_2x2x3_xy", design().geometry(for: .lid), references: refs)
    }

    @Test func `closed assembly footprint and part count`() async throws {
        let bin = try refs.metrics("bin_2x2x3_xy")
        let closed = try await measure(design().geometry(for: .bothClosed))
        #expect(abs(closed.min.x - bin.min.x) < 0.05 && abs(closed.max.x - bin.max.x) < 0.05)
        #expect(abs(closed.min.y - bin.min.y) < 0.05 && abs(closed.max.y - bin.max.y) < 0.05)
    }

    @Test func `open assembly moves the lid out along the lid direction`() async throws {
        let closed = try await measure(design().geometry(for: .bothClosed))
        let open = try await measure(design().geometry(for: .bothOpen))
        #expect(open.min.x < closed.min.x - 70)
        #expect(abs(open.volume - closed.volume) < 1e-6)
    }

    @Test func `closed assembly volume is the bin plus the lid`() async throws {
        // Measured: the closed lid and bin overlap by 1.392 mm^3 (bin intersected with lid), a
        // sliver where the lid's tabs and the bin's lip meet. Parts are separate bodies in the
        // model, so the assembly volume is the plain sum of the two references, not their union
        // (union volume 46740.339 mm^3).
        let bin = try refs.metrics("bin_2x2x3_xy")
        let lid = try refs.metrics("lid_2x2x3_xy")
        let closed = try await measure(design().geometry(for: .bothClosed))
        #expect(abs(closed.volume - (bin.volume + lid.volume)) / (bin.volume + lid.volume) < 1e-4)
        let overlap = try await measure(
            design().binSolid(pockets: design().pockets()).intersecting { design().lidBody() })
        #expect(abs(overlap.volume - 1.392) < 0.01)
    }

    @Test func `assemblies have a Bin part and a Lid part`() async throws {
        for part in [LiddedBinPart.bothClosed, .bothOpen] {
            let names = try await ModelFileGenerator.evaluate { evaluator in
                await evaluator.parts(of: design().geometry(for: part)).keys.map(\.name).sorted()
            }
            #expect(names == ["Bin", "Lid"])
        }
    }
}
