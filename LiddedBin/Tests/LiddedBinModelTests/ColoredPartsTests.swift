import Testing
import Foundation
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// The colored models: each piece is split into named, colored parts whose union is exactly the
/// uncolored piece (no overlap and no gap), and every model lists the right parts.
struct ColoredPartsTests {
    /// Volumes of a split of `whole` into `a` and `b`: each part, the whole, the intersection of
    /// the parts and the symmetric difference between their union and the whole.
    struct Split {
        var a: Double, b: Double, whole: Double, overlap: Double, symmetricDifference: Double
    }

    func split(_ whole: any Geometry3D, _ a: any Geometry3D, _ b: any Geometry3D) async throws -> Split {
        let whole = whole.withSegmentation(count: 64)
        let a = a.withSegmentation(count: 64)
        let b = b.withSegmentation(count: 64)
        let union = Union { a; b }
        let difference = Union {
            whole.subtracting { union }
            union.subtracting { whole }
        }
        return try await ModelFileGenerator.evaluate { evaluator in
            Split(
                a: await evaluator.measurements(of: a).volume,
                b: await evaluator.measurements(of: b).volume,
                whole: await evaluator.measurements(of: whole).volume,
                overlap: await evaluator.measurements(of: a.intersecting { b }).volume,
                symmetricDifference: await evaluator.measurements(of: difference).volume
            )
        }
    }

    /// The volume in mm^3 under which an intersection or a symmetric difference counts as empty.
    /// The parts are exact by construction (the body is the bin minus the dividers, the lid
    /// center the plate minus the rim and lip), but their boundary runs along faces of the bin
    /// (the pocket walls, the feet), and Manifold's booleans on coincident faces leave a residue:
    /// measured from 1e-17 to 5e-14 mm^3 for most cases and up to 7.3e-8 mm^3 for the 3x2x3 bin
    /// with the lid up, where even `(bin - dividers) ∩ dividers`, empty by definition, measures
    /// 5.6e-9 mm^3. A real overlap or gap is a sliver at least a mesh face wide; the mutations
    /// that this test must catch are many mm^3.
    static let zeroVolume = LiddedBinDesign.emptyShellVolume

    func expectExactSplit(_ s: Split, _ label: String) {
        #expect(s.a > 0 && s.b > 0, "\(label)")
        #expect(abs(s.a + s.b - s.whole) / s.whole < 1e-6, "\(label): \(s.a) + \(s.b) vs \(s.whole)")
        #expect(abs(s.overlap) < Self.zeroVolume, "\(label): overlap \(s.overlap)")
        #expect(abs(s.symmetricDifference) < Self.zeroVolume,
                "\(label): symmetric difference \(s.symmetricDifference)")
    }

    /// The production defaults with `cornerSegments = 16`.
    func production(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        edit(&c)
        return LiddedBinDesign(c)
    }

    struct Case: CustomTestStringConvertible, Sendable {
        var name: String
        var configuration: LiddedBinConfiguration
        var testDescription: String { name }
    }

    static let cases: [Case] = {
        var defaults = LiddedBinConfiguration()
        defaults.cornerSegments = 16
        var up = defaults
        up.gridX = 3; up.lidOrientation = .up
        var original = LiddedBinConfiguration.openSCADOriginal
        original.cornerSegments = 16
        var multi = defaults
        multi.gridX = 3; multi.compartmentPattern = .multiSize; multi.divX = 3; multi.divY = 3
        return [
            Case(name: "2x2x3 defaults", configuration: defaults),
            Case(name: "2x2x3 defaults, production segmentation", configuration: LiddedBinConfiguration()),
            Case(name: "3x2x3 lid up", configuration: up),
            Case(name: "2x2x3 original", configuration: original),
            Case(name: "3x2x3 multisize", configuration: multi),
        ]
    }()

    @Test(arguments: cases)
    func `bin body and dividers split the bin exactly`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        let pockets = d.pockets()
        let dividers = try #require(d.binDividers(pockets: pockets))
        let s = try await split(d.binSolid(pockets: pockets), d.binBody(pockets: pockets), dividers)
        expectExactSplit(s, c.name)
    }

    @Test(arguments: cases)
    func `lid rim and lip and lid center split the lid exactly`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        // gf_bin_lid as lid-bin.scad builds it: the rim, plus the plate and the tongue minus the
        // tab notches. Not `lidBody()`, which is the union of the two parts.
        let lid = Union {
            d.lidRim()
            Union { d.lidPlateSlab(); d.lidTongue() }.subtracting { d.lidTabs(adjust: true) }
        }
        let s = try await split(lid, d.lidRimAndLip(), d.lidCenter())
        expectExactSplit(s, c.name)
    }

    @Test func `the lid center is the flat plate`() async throws {
        // The center spans exactly the plate thickness; the tongue below it and the rim above it
        // belong to the other part.
        let d = production()
        let center = try await measure(d.lidCenter(), segments: 64)
        let plateZ = d.storageHeight + d.d.hBase - d.fit.thickness - d.fit.vPosTolerance
        #expect(abs(center.min.z - plateZ) < 1e-6)
        #expect(abs(center.max.z - (plateZ + d.fit.thickness)) < 1e-6)
    }

    @Test(arguments: cases)
    func `dividers start at the pocket floor`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        let dividers = try #require(d.binDividers(pockets: d.pockets()))
        let m = try await measure(dividers)
        #expect(abs(m.min.z - d.d.dWall) < 1e-6, "\(c.name): \(m.min.z)")
        // The dividers end at the top of the floor block, below the lid's plate
        #expect(abs(m.max.z - d.floorTop) < 1e-6, "\(c.name): \(m.max.z)")
    }

    @Test func `dividers stay clear of the wall and the compartments`() async throws {
        let d = production()
        let pockets = try #require(d.pockets())
        let dividers = try #require(d.binDividers(pockets: pockets))
        let (wall, inPockets, outside) = try await ModelFileGenerator.evaluate { evaluator in
            (await evaluator.measurements(of: dividers.intersecting { d.binWall() }).volume,
             await evaluator.measurements(of: dividers.intersecting { pockets }).volume,
             await evaluator.measurements(of: dividers.subtracting { d.dividerRegion() }).volume)
        }
        #expect(abs(wall) < Self.zeroVolume && abs(inPockets) < Self.zeroVolume && abs(outside) < Self.zeroVolume)
    }

    @Test(arguments: cases)
    func `every part is one piece with no empty shells`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        let pockets = d.pockets()
        let parts: [(String, any Geometry3D)] = [
            ("body", d.binBody(pockets: pockets)), ("dividers", try #require(d.binDividers(pockets: pockets))),
            ("rim", d.lidRimAndLip()), ("center", d.lidCenter()),
        ]
        for (name, part) in parts {
            let volumes = try await ModelFileGenerator.evaluate { evaluator in
                var volumes: [Double] = []
                for component in await evaluator.components(of: part) {
                    volumes.append(await evaluator.measurements(of: component).volume)
                }
                return volumes
            }
            #expect(volumes.count == 1, "\(c.name) \(name): \(volumes)")
        }
    }

    @Test func `a bin without dividers has no dividers part and its body is the whole bin`() async throws {
        // No pockets (a hollow bin) for a 0, and one compartment for 1 by 1, in both patterns
        let edits: [(String, (inout LiddedBinConfiguration) -> Void)] = [
            ("divX 0", { $0.divX = 0 }), ("divY 0", { $0.divY = 0 }),
            ("1 by 1", { $0.divX = 1; $0.divY = 1 }),
            ("multisize 1 by 1", { $0.compartmentPattern = .multiSize; $0.divX = 1; $0.divY = 1 }),
        ]
        for (name, edit) in edits {
            let d = production(edit)
            let colored = d.coloredGeometry(for: .bin, colors: .defaults)
            let parts = try await partInfo(colored)
            #expect(parts.map(\.name) == [LiddedBinDesign.binBodyPartName], "\(name)")
            let whole = try await measure(d.geometry(for: .bin))
            #expect(abs((parts.first?.volume ?? 0) - whole.volume) < 1e-9 * whole.volume, "\(name)")
            let s = try await ModelFileGenerator.evaluate { evaluator in
                let body = await evaluator.parts(of: colored).first?.value ?? Empty()
                let difference = Union {
                    body.subtracting { d.geometry(for: .bin) }
                    d.geometry(for: .bin).subtracting { body }
                }
                return await evaluator.measurements(of: difference, scope: .mainPart).volume
            }
            #expect(abs(s) < Self.zeroVolume, "\(name)")
            let assembly = try await partInfo(d.coloredGeometry(for: .bothClosed, colors: .defaults))
            #expect(assembly.map(\.name) == [LiddedBinDesign.binBodyPartName, LiddedBinDesign.lidCenterPartName,
                                             LiddedBinDesign.lidRimPartName], "\(name)")
        }
        #expect(production { $0.divX = 0 }.binDividers(pockets: nil) == nil)
    }

    struct PartInfo: Sendable {
        var name: String
        var material: Material?
        var volume: Double
        var min: Vector3D, max: Vector3D
    }

    /// The parts of `geometry`, sorted by name, with their default material, volume and bounds.
    func partInfo(_ geometry: any Geometry3D) async throws -> [PartInfo] {
        let geometry = geometry.withSegmentation(count: 64)
        return try await ModelFileGenerator.evaluate { evaluator in
            var result: [PartInfo] = []
            for (part, g) in await evaluator.parts(of: geometry) {
                // A part's geometry contains its own part declaration, so it is measured with the
                // main part only.
                let m = await evaluator.measurements(of: g, scope: .mainPart)
                result.append(PartInfo(name: part.name, material: part.defaultMaterial, volume: await m.volume,
                                       min: m.boundingBox?.minimum ?? .zero, max: m.boundingBox?.maximum ?? .zero))
            }
            return result.sorted { $0.name < $1.name }
        }
    }

    /// Four distinct colors, so that a swap between any two parts shows.
    static let distinct = LiddedBinColors(
        binBody: Color(hex: "#102030"), dividers: Color(hex: "#405060"),
        lidRim: Color(hex: "#708090"), lidCenter: Color(hex: "#A0B0C0"))

    @Test func `default colors`() {
        let c = LiddedBinColors.defaults
        #expect(c.binBody == Color(red: 0x58 / 255.0, green: 0x7A / 255.0, blue: 0x9E / 255.0))
        #expect(c.dividers == Color(red: 0xE8 / 255.0, green: 0x91 / 255.0, blue: 0x2D / 255.0))
        #expect(c.lidRim == c.binBody)
        #expect(c.lidCenter == Color(red: 0xC8 / 255.0, green: 0xCD / 255.0, blue: 0xD6 / 255.0))
    }

    @Test(arguments: [ColoredPartsTests.distinct, LiddedBinColors.defaults])
    func `each colored model has its named parts in their colors`(_ colors: LiddedBinColors) async throws {
        let d = production()
        let bin = [(LiddedBinDesign.binBodyPartName, colors.binBody), (LiddedBinDesign.dividersPartName, colors.dividers)]
        let lid = [(LiddedBinDesign.lidCenterPartName, colors.lidCenter), (LiddedBinDesign.lidRimPartName, colors.lidRim)]
        let expected: [(LiddedBinPart, [(String, Color)])] = [
            (.bin, bin), (.lid, lid), (.lidOnPlate, lid),
            (.bothClosed, bin + lid), (.bothOpen, bin + lid), (.bothSeparated, bin + lid),
            (.binSlice, [(LiddedBinDesign.binBodyPartName, colors.binBody)]),
        ]
        for (part, list) in expected {
            let parts = try await partInfo(d.coloredGeometry(for: part, colors: colors))
            let want = list.sorted { $0.0 < $1.0 }
            #expect(parts.map(\.name) == want.map(\.0), "\(part)")
            for (info, (name, color)) in zip(parts, want) {
                #expect(info.material == Material.plain(color), "\(part) \(name)")
                #expect(info.volume > 0, "\(part) \(name)")
            }
            // The parts hold the whole uncolored model, and nothing is left in the main part
            let uncolored = try await measure(d.geometry(for: part))
            let total = parts.map(\.volume).reduce(0, +)
            #expect(abs(total - uncolored.volume) < 1e-6 * uncolored.volume, "\(part)")
        }
    }

    @Test func `colored placements match the uncolored ones`() async throws {
        let d = production()
        // The single pieces: the union of the parts' bounds is the uncolored piece's bounds
        for part in [LiddedBinPart.bin, .lid, .lidOnPlate] {
            let parts = try await partInfo(d.coloredGeometry(for: part, colors: .defaults))
            let whole = try await measure(d.geometry(for: part))
            expectBounds(parts, whole.min, whole.max, "\(part)")
        }
        // The assemblies: the bin's parts span the uncolored "Bin" part, the lid's the "Lid" part
        for part in [LiddedBinPart.bothClosed, .bothOpen, .bothSeparated] {
            let colored = try await partInfo(d.coloredGeometry(for: part, colors: .defaults))
            let plain = try await partInfo(d.geometry(for: part))
            let binPart = try #require(plain.first { $0.name == LiddedBinDesign.binPartName })
            let lidPart = try #require(plain.first { $0.name == LiddedBinDesign.lidPartName })
            let binNames = [LiddedBinDesign.binBodyPartName, LiddedBinDesign.dividersPartName]
            expectBounds(colored.filter { binNames.contains($0.name) }, binPart.min, binPart.max, "\(part) bin")
            expectBounds(colored.filter { !binNames.contains($0.name) }, lidPart.min, lidPart.max, "\(part) lid")
            if part == .bothSeparated {
                for p in colored { #expect(p.min.z > -1e-6, "\(p.name) \(p.min.z)") }
            }
        }
    }

    func expectBounds(_ parts: [PartInfo], _ min: Vector3D, _ max: Vector3D, _ label: String) {
        #expect(parts.count == 2, "\(label)")
        let lo = Vector3D(parts.map(\.min.x).min()!, parts.map(\.min.y).min()!, parts.map(\.min.z).min()!)
        let hi = Vector3D(parts.map(\.max.x).max()!, parts.map(\.max.y).max()!, parts.map(\.max.z).max()!)
        for (a, b) in [(lo.x, min.x), (lo.y, min.y), (lo.z, min.z), (hi.x, max.x), (hi.y, max.y), (hi.z, max.z)] {
            #expect(abs(a - b) < 1e-6, "\(label): \(lo) \(hi) vs \(min) \(max)")
        }
    }

    /// The exported 3MF of the separated assembly: one object per part with its name, and a color
    /// group with the part's color.
    @Test func `the 3MF names and colors every part`() async throws {
        let d = production()
        let file = try await ModelFileGenerator.build(named: "colors") {
            d.coloredGeometry(for: .bothSeparated, colors: Self.distinct)
        }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "lidded-bin-3mf-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = directory.appending(path: "model.3mf")
        try await file.write(to: archive)

        func unzip(_ entry: String) throws -> String {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/unzip")
            process.arguments = ["-p", archive.path, entry]
            process.standardOutput = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }

        let root = try unzip("3D/3dmodel.model")
        let expected = [("bin-body", "Bin body", "#102030"), ("dividers", "Dividers", "#405060"),
                        ("lid-rim-and-lip", "Lid rim and lip", "#708090"), ("lid-center", "Lid center", "#a0b0c0")]
        #expect(root.components(separatedBy: "<item ").count - 1 == expected.count)
        for (file, name, color) in expected {
            #expect(root.contains("p:path=\"/3D/\(file).model\""), "\(file)")
            let model = try unzip("3D/\(file).model")
            #expect(model.contains("name=\"\(name)\""), "\(file)")
            #expect(model.contains("<m:color color=\"\(color)\"/>"), "\(file)")
        }
    }
}
