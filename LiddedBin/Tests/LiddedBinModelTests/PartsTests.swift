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

    @Test func `lid on plate rests at z 0 with the same volume as the lid`() async throws {
        let lid = try await measure(design().geometry(for: .lid))
        let plate = try await measure(design().geometry(for: .lidOnPlate))
        #expect(abs(plate.min.z) < 1e-6)
        #expect(abs(plate.volume - lid.volume) < 1e-9)
    }

    @Test func `closed assembly parts are named Bin and Lid with the unchanged model`() async throws {
        let names = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.parts(of: design().geometry(for: .bothClosed)).keys.map(\.name).sorted()
        }
        #expect(names == ["Bin", "Lid"])
        let bin = try refs.metrics("bin_2x2x3_xy")
        let lid = try refs.metrics("lid_2x2x3_xy")
        let closed = try await measure(design().geometry(for: .bothClosed))
        #expect(abs(closed.volume - (bin.volume + lid.volume)) / (bin.volume + lid.volume) < 1e-4)
    }

    struct SeparatedCase: CustomTestStringConvertible, Sendable {
        var x: Int, y: Int, z: Double
        var lid: LidOrientation = .left
        var alongX: Bool
        var testDescription: String { "\(x)x\(y)x\(z) \(lid) alongX=\(alongX)" }
    }

    @Test(arguments: [
        SeparatedCase(x: 2, y: 2, z: 3, alongX: true),
        SeparatedCase(x: 2, y: 4, z: 3, alongX: true),
        SeparatedCase(x: 4, y: 2, z: 3, alongX: false),
        SeparatedCase(x: 2, y: 2, z: 3, lid: .right, alongX: true),
        SeparatedCase(x: 2, y: 2, z: 3, lid: .up, alongX: true),
        SeparatedCase(x: 2, y: 2, z: 3, lid: .down, alongX: true),
    ])
    func `separated layout`(_ c: SeparatedCase) async throws {
        let d = design { $0.gridX = c.x; $0.gridY = c.y; $0.gridZ = c.z; $0.lidOrientation = c.lid }
        let geometry = d.geometry(for: .bothSeparated).withSegmentation(count: 64)
        let names = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.parts(of: geometry).keys.map(\.name).sorted()
        }
        #expect(names == ["Bin", "Lid"])

        // Each part's own bounds and volume, and the volume where the two intersect. A part's
        // geometry contains its own part declaration, so it is measured with the main part only.
        let (bin, lid, overlapVolume) = try await ModelFileGenerator.evaluate { evaluator in
            let parts = await evaluator.parts(of: geometry)
            let binPart = try #require(parts.first { $0.key.name == "Bin" }?.value)
            let lidPart = try #require(parts.first { $0.key.name == "Lid" }?.value)
            func metrics(_ g: any Geometry3D) async -> Metrics {
                let m = await evaluator.measurements(of: g, scope: .mainPart)
                return Metrics(volume: await m.volume, min: m.boundingBox?.minimum ?? .zero,
                               max: m.boundingBox?.maximum ?? .zero)
            }
            let overlap = await evaluator.measurements(of: binPart.intersecting { lidPart }, scope: .mainPart)
            return (await metrics(binPart), await metrics(lidPart), await overlap.volume)
        }
        #expect(overlapVolume == 0)
        #expect(abs(bin.min.z) < 1e-6)
        #expect(abs(lid.min.z) < 1e-6)

        let gap = c.alongX ? lid.min.x - bin.max.x : lid.min.y - bin.max.y
        #expect(abs(gap - LiddedBinDesign.separatedGap) < 1e-6)
        #expect(LiddedBinDesign.separatedGap == 10)
        if c.alongX {
            #expect(abs((bin.min.x + lid.max.x) / 2) < 1e-6)
            #expect(abs(bin.min.y + bin.max.y) < 1e-6 && abs(lid.min.y + lid.max.y) < 1e-6)
            #expect(bin.min.y < lid.max.y && lid.min.y < bin.max.y)
        } else {
            #expect(abs((bin.min.y + lid.max.y) / 2) < 1e-6)
            #expect(abs(bin.min.x + bin.max.x) < 1e-6 && abs(lid.min.x + lid.max.x) < 1e-6)
            #expect(bin.min.x < lid.max.x && lid.min.x < bin.max.x)
        }

        let whole = try await measure(geometry)
        let binAlone = try await measure(d.geometry(for: .bin))
        let lidAlone = try await measure(d.geometry(for: .lidOnPlate))
        #expect(abs(whole.volume - (binAlone.volume + lidAlone.volume)) < 1e-6)
        #expect(abs(bin.volume - binAlone.volume) < 1e-6 && abs(lid.volume - lidAlone.volume) < 1e-6)
    }
}
