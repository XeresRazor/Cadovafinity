import Testing
import Foundation
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// Behavior of the lid fit controls. There is no OpenSCAD reference for these, so they are
/// measured with ray casts on the closed assembly.
///
/// The lid clearance is the side gap between the vertical plate edge and the slot face. The tongue
/// above the plate has a chamfer facing the slot roof; its offset is derived from the clearance
/// (`min(0.30, clearance + 0.10)`). The lid chamfer is the rise of the slot roof, which the
/// tongue's chamfer follows: 0.8 is the original 45 degree roof.
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

    /// Perpendicular gap between the tongue chamfer and the slot roof for the original 45 degree
    /// roof (lid chamfer 0.8), from a ray 0.45 mm above the plate top (about mid tongue height).
    func chamferGap(_ design: LiddedBinDesign) async throws -> Double {
        let f = try await faces(design, z: plateTop(design) + 0.45)
        return (f.slot - f.edge) / 2.0.squareRoot()
    }

    /// The slot roof and the tongue chamfer at x = 0, with heights above the plate top.
    struct Roof {
        /// Rise over run of the slot roof and of the tongue's chamfer.
        var slope: Double, chamferSlope: Double
        /// Height of the roof tip, where the roof meets the inside of the wall.
        var rise: Double
        /// Horizontal run of the roof from the slot face to the tip.
        var run: Double
        /// Perpendicular gap between the roof and the tongue chamfer.
        var gap: Double
        /// Height of the tongue's highest point.
        var peak: Double
        var angle: Double { Foundation.atan(slope) * 180 / .pi }
        var chamferAngle: Double { Foundation.atan(chamferSlope) * 180 / .pi }
    }

    /// Measures the roof with rays along +y (the roof is the bin's first surface, the tongue
    /// chamfer the lid's last) and the tongue's peak with rays down along -z.
    func roof(_ design: LiddedBinDesign) async throws -> Roof {
        let top = plateTop(design)
        let bin = design.binSolid(pockets: design.pockets())
        let lid = design.lidBody()
        return try await ModelFileGenerator.evaluate { evaluator in
            func slotY(_ u: Double) async -> Double {
                await evaluator.surfaces(of: bin, from: Vector3D(0, 0, top + u), in: .positiveY)
                    .first { $0.transition == .entering }?.position.y ?? .nan
            }
            func edgeY(_ u: Double) async -> Double {
                await evaluator.surfaces(of: lid, from: Vector3D(0, 0, top + u), in: .positiveY)
                    .last { $0.transition == .exiting }?.position.y ?? .nan
            }
            // The roof line from two heights that are on the roof for every supported rise
            let u1 = 0.15, u2 = 0.55
            let r1 = await slotY(u1), r2 = await slotY(u2)
            let slope = (u2 - u1) / (r1 - r2)
            func roofY(_ u: Double) -> Double { r2 - (u - u2) / slope }

            // Walk up until the first surface leaves the roof line, then intersect the roof line
            // with the wall surface just above that height
            var u = u2
            while u < 2.6, abs(await slotY(u + 0.01) - roofY(u + 0.01)) < 0.005 { u += 0.01 }
            let b1u = u + 0.03, b2u = u + 0.07
            let b1 = await slotY(b1u), b2 = await slotY(b2u)
            let m = (b2 - b1) / (b2u - b1u)
            let rise = (r2 + u2 / slope - b1 + b1u * m) / (m + 1 / slope)
            let slotFace = await slotY(-design.fit.thickness / 2)
            let run = slotFace - roofY(rise)

            let c1 = await edgeY(0.25), c2 = await edgeY(0.5)
            let chamferSlope = (0.5 - 0.25) / (c1 - c2)
            let horizontal = await slotY(0.4) - edgeY(0.4)
            let gap = horizontal * slope / (1 + slope * slope).squareRoot()

            var peak = -Double.infinity
            for i in 0...640 {
                let y = 39.0 + 0.0025 * Double(i)
                let z = await evaluator.surfaces(of: lid, from: Vector3D(0, y, top + 4), in: .negativeZ)
                    .first { $0.transition == .entering }?.position.z ?? -.infinity
                peak = max(peak, z - top)
            }
            return Roof(slope: slope, chamferSlope: chamferSlope, rise: rise, run: run, gap: gap, peak: peak)
        }
    }

    /// The default fit (clearance 0.20) with the given lid chamfer.
    func chamferDesign(_ chamfer: Double) -> LiddedBinDesign {
        design { $0.lidClearance = 0.20; $0.lidChamfer = chamfer }
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

    @Test func `original lid chamfer is the 45 degree roof`() async throws {
        let r = try await roof(design())
        print("roof original: rise \(r.rise) run \(r.run) angle \(r.angle) chamfer \(r.chamferAngle) gap \(r.gap) peak \(r.peak)")
        #expect(abs(r.rise - 0.8) < 0.02, "rise \(r.rise)")
        #expect(abs(r.angle - 45) < 1, "angle \(r.angle)")
        #expect(LiddedBinDesign(.openSCADOriginal).roofSlope == 1)
        #expect(LiddedBinDesign(.openSCADOriginal).lidRoofDrop == 0)
    }

    @Test func `default lid chamfer rises 1_4 mm`() async throws {
        let d = LiddedBinDesign({ var c = LiddedBinConfiguration(); c.cornerSegments = 16; return c }())
        let r = try await roof(d)
        let expected = Foundation.atan(1.4 / d.roofFaceRun) * 180 / .pi
        print("roof default: rise \(r.rise) run \(r.run) angle \(r.angle) expected \(expected)")
        #expect(abs(d.roofFaceRun - 0.7) < 1e-9)
        #expect(abs(r.angle - expected) < 1, "angle \(r.angle) expected \(expected)")
        #expect(abs(r.rise - 1.4) < 0.05, "rise \(r.rise)")
    }

    @Test(arguments: [0.8, 1.4, 2.0])
    func `tongue chamfer follows the roof`(chamfer: Double) async throws {
        let r = try await roof(chamferDesign(chamfer))
        print("roof \(chamfer): rise \(r.rise) run \(r.run) angle \(r.angle) chamfer \(r.chamferAngle) gap \(r.gap) peak \(r.peak)")
        #expect(abs(r.chamferAngle - r.angle) < 1, "roof \(r.angle) chamfer \(r.chamferAngle)")
        #expect(abs(r.gap - 0.229) < 0.02, "gap \(r.gap)")
        #expect(abs(r.rise - chamfer) < 0.05, "rise \(r.rise)")
    }

    @Test func `the tongue grows with the lid chamfer`() async throws {
        var peaks: [Double] = []
        for c in [0.8, 1.4, 2.0] { peaks.append(try await roof(chamferDesign(c)).peak) }
        print("tongue peaks above the plate top (0.8, 1.4, 2.0): \(peaks)")
        #expect(peaks[0] < peaks[1] && peaks[1] < peaks[2])
        #expect(peaks[2] < 2.0)
    }

    @Test func `a tighter clearance gives a taller tongue`() async throws {
        let tight = try await roof(design { $0.lidClearance = 0.10; $0.lidChamfer = 1.4 }).peak
        let normal = try await roof(chamferDesign(1.4)).peak
        print("tongue peak at chamfer 1.4: clearance 0.10 \(tight), clearance 0.20 \(normal)")
        #expect(tight > normal)
    }

    @Test func `the default lid chamfer still fits`() async throws {
        let d = LiddedBinDesign({ var c = LiddedBinConfiguration(); c.cornerSegments = 16; return c }())
        let volume = try await interference(d)
        print("lid/bin interference, default settings: \(volume) mm^3")
        #expect(volume < 8)
        let steepest = try await interference(chamferDesign(2.0))
        print("lid/bin interference, lid chamfer 2.0: \(steepest) mm^3")
        #expect(steepest < 8)
    }

    @Test func `default design derives the tongue offset from the clearance`() {
        #expect(LiddedBinConfiguration().lidClearance == 0.20)
        #expect(LiddedBinDesign(LiddedBinConfiguration()).fit.lipClearance == 0.30)
        #expect(LiddedBinDesign(.openSCADOriginal).fit.lipClearance == 0.30)
        var c = LiddedBinConfiguration()
        c.lidClearance = 0.10
        #expect(abs(LiddedBinDesign(c).fit.lipClearance - 0.20) < 1e-9)
        #expect(LiddedBinDesign(LiddedBinConfiguration()).fit.chamfer == 1.4)
        #expect(LiddedBinDesign(.openSCADOriginal).fit.chamfer == 0.8)
        #expect(LidFit().chamfer == 0.8)
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
