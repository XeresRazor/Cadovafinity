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
    /// The parts are exact by construction (the body is the bin minus the dividers, the lid rim
    /// and lip the lid minus the center), but their boundary runs along faces of the bin
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

    /// The lid cases: the bin cases plus a tighter clearance and the smallest lid.
    static let lidCases: [Case] = {
        var tight = LiddedBinConfiguration()
        tight.cornerSegments = 16
        tight.lidClearance = 0.10
        var small = LiddedBinConfiguration()
        small.cornerSegments = 16
        small.gridX = 1; small.gridY = 1
        return cases + [
            Case(name: "2x2x3 clearance 0.10", configuration: tight),
            Case(name: "1x1x3 defaults", configuration: small),
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

    @Test(arguments: lidCases)
    func `lid rim and lip and lid center split the lid exactly`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        // gf_bin_lid as lid-bin.scad builds it: the rim, plus the plate and the tongue minus the
        // tab notches. Not `lidBody()`, which is the union of the two parts.
        let lid = Union {
            d.lidRim()
            Union { d.lidPlateSlab(); d.lidTongue() }.subtracting { d.lidTabs(adjust: true) }
        }
        let s = try await split(lid, d.lidRimAndLip(), d.lidCenter())
        print("lid split \(c.name): rim and lip \(s.a) center \(s.b) lid \(s.whole) overlap \(s.overlap) sym \(s.symmetricDifference)")
        expectExactSplit(s, c.name)
    }

    /// The lid's plate edge and the tongue's foot along the ray across the +y side at x = 0: the
    /// plate edge (the slab's exit at mid plate thickness) and the width of the tongue's foot,
    /// from the plate edge to the tongue's inner face just above the plate top.
    func plateEdgeAndFoot(_ d: LiddedBinDesign) async throws -> (edge: Double, foot: Double) {
        let top = d.lidPlateZ + d.fit.thickness
        let slab = d.lidPlateSlab().withSegmentation(count: 64)
        let tongue = d.lidTongue().withSegmentation(count: 64)
        return try await ModelFileGenerator.evaluate { evaluator in
            let edge = await evaluator.surfaces(of: slab, from: Vector3D(0, 0, top - d.fit.thickness / 2), in: .positiveY)
                .last { $0.transition == .exiting }?.position.y ?? .nan
            let inner = await evaluator.surfaces(of: tongue, from: Vector3D(0, 0, top + 0.001), in: .positiveY)
                .first { $0.transition == .entering }?.position.y ?? .nan
            return (edge, edge - inner)
        }
    }

    @Test(arguments: [0.10, 0.20, 0.30])
    func `the edge band is the width of the tongue's foot and follows the lid clearance`(clearance: Double) async throws {
        let d = production { $0.lidClearance = clearance }
        let measured = try await plateEdgeAndFoot(d)
        print("edge band at clearance \(clearance): design \(d.lidEdgeBand) measured foot \(measured.foot)")
        #expect(abs(d.lidEdgeBand - measured.foot) < 0.02, "\(clearance): \(d.lidEdgeBand) vs \(measured.foot)")
    }

    @Test(arguments: [lidCases[0], lidCases[2], lidCases[3], lidCases[6]])
    func `the lid center is the plate inside the edge band`(_ c: Case) async throws {
        // The center spans exactly the plate thickness, and its bounds are those of the plate
        // inset by the width of the tongue's foot (measured, not taken from the design) on all
        // four sides.
        let d = LiddedBinDesign(c.configuration)
        let w = try await plateEdgeAndFoot(d).foot
        let center = try await measure(d.lidCenter(), segments: 64)
        let plate = try await measure(d.lidPlateSlab(), segments: 64)
        #expect(abs(center.min.z - d.lidPlateZ) < 1e-6, "\(c.name)")
        #expect(abs(center.max.z - (d.lidPlateZ + d.fit.thickness)) < 1e-6, "\(c.name)")
        let insets = [center.min.x - plate.min.x, plate.max.x - center.max.x,
                      center.min.y - plate.min.y, plate.max.y - center.max.y]
        for inset in insets {
            #expect(abs(inset - w) < 0.05, "\(c.name): insets \(insets), foot \(w)")
        }
    }

    /// Where a ray from outside the lid toward its middle, at mid plate thickness, meets the two
    /// parts: the first entry of the rim and lip part, the first entry of the center part, and the
    /// last exit of the rim and lip part before the center begins, as distances along the ray.
    struct EdgeCrossing { var rim: Double, rimEnd: Double, center: Double }

    func edgeCrossing(_ d: LiddedBinDesign, from start: Vector2D, _ direction: Direction3D,
                      alongX: Bool) async throws -> EdgeCrossing {
        let origin = Vector3D(start.x, start.y, d.lidPlateZ + d.fit.thickness / 2)
        let rim = d.lidRimAndLip().withSegmentation(count: 64)
        let center = d.lidCenter().withSegmentation(count: 64)
        return try await ModelFileGenerator.evaluate { evaluator in
            func axis(_ v: Vector3D) -> Double { alongX ? v.x : v.y }
            let rimHits = await evaluator.surfaces(of: rim, from: origin, in: direction)
            let centerHits = await evaluator.surfaces(of: center, from: origin, in: direction)
            let o = axis(origin)
            let centerStart = centerHits.first { $0.transition == .entering }.map { abs(axis($0.position) - o) } ?? .nan
            let rimStart = rimHits.first { $0.transition == .entering }.map { abs(axis($0.position) - o) } ?? .nan
            let rimEnd = rimHits.filter { $0.transition == .exiting }
                .map { abs(axis($0.position) - o) }.filter { $0 < centerStart + 0.01 }.max() ?? .nan
            return EdgeCrossing(rim: rimStart, rimEnd: rimEnd, center: centerStart)
        }
    }

    @Test(arguments: [lidCases[0], lidCases[2], lidCases[5]])
    func `the rim and lip color wraps the plate edge on every side`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        let w = try await plateEdgeAndFoot(d).foot
        let plate = try await measure(d.lidPlateSlab(), segments: 64)
        let far = 200.0
        // The middle of each side (one of them the open end, with the end rim), from outside
        let rays: [(String, Vector2D, Direction3D, Bool, Double)] = [
            ("+y side", [0, far], .negativeY, false, far - plate.max.y),
            ("-y side", [0, -far], .positiveY, false, far + plate.min.y),
            ("+x side", [far, 0], .negativeX, true, far - plate.max.x),
            ("-x side", [-far, 0], .positiveX, true, far + plate.min.x),
        ]
        for (name, start, direction, alongX, edge) in rays {
            let e = try await edgeCrossing(d, from: start, direction, alongX: alongX)
            // The rim and lip part is met first, at or outside the plate edge (the end rim
            // reaches past it), and runs without a gap to where the center starts, w further in
            #expect(e.rim <= edge + 0.01, "\(c.name) \(name): rim \(e.rim) edge \(edge)")
            #expect(abs(e.center - (edge + w)) < 0.02, "\(c.name) \(name): center \(e.center) edge \(edge) w \(w)")
            #expect(abs(e.rimEnd - e.center) < 0.01, "\(c.name) \(name): rim ends \(e.rimEnd) center \(e.center)")
        }
        // A corner: a ray along -y through the rounded corner of the plate (radius r about the
        // corner center), where the band, measured along the ray, is wider than w
        let r = (d.d.rFo1 - d.fit.plateInset) / 2 + 0.001
        let cx = plate.max.x - r, cy = plate.max.y - r
        let x = cx + (r - w) * 0.7
        let outer = cy + (r * r - (x - cx) * (x - cx)).squareRoot()
        let inner = cy + ((r - w) * (r - w) - (x - cx) * (x - cx)).squareRoot()
        let e = try await edgeCrossing(d, from: [x, far], .negativeY, alongX: false)
        #expect(e.rim <= far - outer + 0.02, "\(c.name) corner: rim \(e.rim) vs \(far - outer)")
        #expect(abs(e.center - (far - inner)) < 0.02, "\(c.name) corner: center \(e.center) vs \(far - inner)")
        #expect(abs(e.rimEnd - e.center) < 0.01, "\(c.name) corner")
    }

    @Test func `the lid center has no material in the edge band`() async throws {
        // The band is built here from the measured width of the tongue's foot: the center has no
        // volume in it (all round, corners and the notches included), and the rim and lip part
        // has none in the plate inside it
        for c in [Self.lidCases[0], Self.lidCases[5]] {
            let d = LiddedBinDesign(c.configuration)
            let w = try await plateEdgeAndFoot(d).foot
            let footprint = d.lidPlateFootprint()
            let band = footprint.subtracting { footprint.offset(amount: -(w - 0.01), style: .round) }
                .extruded(height: d.fit.thickness).translated(z: d.lidPlateZ)
            let inside = footprint.offset(amount: -(w + 0.01), style: .round)
                .extruded(height: d.fit.thickness - 0.02).translated(z: d.lidPlateZ + 0.01)
            let center = d.lidCenter(), rim = d.lidRimAndLip()
            let (inBand, rimInside, bandVolume) = try await ModelFileGenerator.evaluate { evaluator in
                (await evaluator.measurements(of: center.intersecting { band }.withSegmentation(count: 64)).volume,
                 await evaluator.measurements(of: rim.intersecting { inside }.withSegmentation(count: 64)).volume,
                 await evaluator.measurements(of: band.withSegmentation(count: 64)).volume)
            }
            #expect(bandVolume > 100, "\(c.name): \(bandVolume)")
            #expect(abs(inBand) < Self.zeroVolume, "\(c.name): center in the band \(inBand)")
            #expect(abs(rimInside) < Self.zeroVolume, "\(c.name): rim and lip inside the band \(rimInside)")
        }
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

    @Test(arguments: lidCases.dropFirst(cases.count))
    func `the lid parts are one piece each with no empty shells`(_ c: Case) async throws {
        let d = LiddedBinDesign(c.configuration)
        for (name, part) in [("rim", d.lidRimAndLip()), ("center", d.lidCenter())] {
            let count = try await ModelFileGenerator.evaluate { evaluator in
                await evaluator.components(of: part).count
            }
            #expect(count == 1, "\(c.name) \(name): \(count)")
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

    /// The compartment counts are documented as: 1 is a single compartment with no dividers, 2 adds
    /// one divider, and each further compartment adds another (N compartments, N - 1 dividers).
    /// 0 gives the same open bin as 1, up to the interior corners.
    @Test func `compartment counts give one fewer divider and 0 and 1 give none`() async throws {
        // With one compartment along Y, every divider is a separate wall
        for n in 2...5 {
            let d = production { $0.divX = n; $0.divY = 1 }
            let dividers = try #require(d.binDividers(pockets: d.pockets()))
            let walls = try await ModelFileGenerator.evaluate { evaluator in
                await evaluator.components(of: dividers).count
            }
            #expect(walls == n - 1, "\(n) compartments: \(walls) dividers")
        }
        for (x, y) in [(0, 0), (1, 1), (0, 1), (1, 0), (1, 6), (6, 1)] where x < 2 && y < 2 {
            let parts = try await partInfo(production { $0.divX = x; $0.divY = y }.coloredGeometry(for: .bin, colors: .defaults))
            #expect(!parts.contains { $0.name == LiddedBinDesign.dividersPartName }, "\(x) by \(y)")
        }
        // 1 compartment along X with 2 along Y has one divider, along the other axis
        let alongY = try await partInfo(production { $0.divX = 1; $0.divY = 2 }.coloredGeometry(for: .bin, colors: .defaults))
        #expect(alongY.contains { $0.name == LiddedBinDesign.dividersPartName })
    }

    /// 0 and 1 compartments give nearly the same bin. A single compartment keeps a thin layer of
    /// material (about 0.4 mm) on the inside of the wall, which 0 cuts away: measured for the 2x2x3
    /// default bin at 64 segments, 0 is 23118 mm^3, 1 is 24804 mm^3, and they differ by 1686 mm^3
    /// (6.8 percent of the volume), all of it in a ring along the wall between z 6.1 and 20.9.
    @Test func `0 and 1 compartments differ only in a thin layer along the wall`() async throws {
        let zero = production { $0.divX = 0; $0.divY = 0 }.geometry(for: .bin).withSegmentation(count: 64)
        let one = production { $0.divX = 1; $0.divY = 1 }.geometry(for: .bin).withSegmentation(count: 64)
        let difference = Union {
            zero.subtracting { one }
            one.subtracting { zero }
        }
        let (a, b, d) = try await ModelFileGenerator.evaluate { evaluator in
            (await evaluator.measurements(of: zero).volume, await evaluator.measurements(of: one).volume,
             await evaluator.measurements(of: difference).volume)
        }
        #expect(abs(a - 23118) < 20 && abs(b - 24804) < 20 && abs(d - 1686) < 20, "\(a) \(b) \(d)")
        #expect(a < b && d / b < 0.1)
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

    /// The exported 3MF of the separated and the closed assemblies: one object per part with its name, and a color
    /// group with the part's color.
    @Test(arguments: [LiddedBinPart.bothSeparated, .bothClosed])
    func `the 3MF names and colors every part`(_ part: LiddedBinPart) async throws {
        let d = production()
        let file = try await ModelFileGenerator.build(named: "colors") {
            d.coloredGeometry(for: part, colors: Self.distinct)
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
