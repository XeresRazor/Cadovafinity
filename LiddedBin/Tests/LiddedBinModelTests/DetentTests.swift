import Testing
import Foundation
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// Behavior of the seated detent catch. There is no OpenSCAD reference for it, so it is measured
/// with ray casts and intersection volumes around the detents at the closed end.
///
/// Coordinates: `a` is the distance from the detent's reference position (`lidTabs`' tab
/// position) toward the closed end, along the slide direction. `w` is the world coordinate across
/// the slide direction, toward the side wall the measured bump is on (+y for left and right, +x
/// for up and down); the slot face is at w = 40.55 for the 2x2 bin.
struct DetentTests {
    /// The default design (seated detent) with `cornerSegments = 16`.
    func seated(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        edit(&c)
        return LiddedBinDesign(c)
    }

    struct Frame {
        var tab: Vector2D, closed: Vector2D, across: Vector2D
        func point(a: Double, w: Double, z: Double) -> Vector3D {
            Vector3D(tab.x * abs(closed.x) + a * closed.x + w * across.x,
                     tab.y * abs(closed.y) + a * closed.y + w * across.y, z)
        }
        func a(_ p: Vector3D) -> Double { (p.x - tab.x) * closed.x + (p.y - tab.y) * closed.y }
        func w(_ p: Vector3D) -> Double { p.x * across.x + p.y * across.y }
        var alongClosed: Direction3D { Direction3D(Vector3D(closed.x, closed.y, 0)) }
        var alongAcross: Direction3D { Direction3D(Vector3D(across.x, across.y, 0)) }
    }

    func frame(_ design: LiddedBinDesign) -> Frame {
        let m = design.lidDirection
        let d = design.d
        let tab = Vector2D(m.x * (-(d.lGrid * design.gridX - 0.5) / 2 + d.rBase + 0.6),
                           m.y * (-(d.lGrid * design.gridY - 0.5) / 2 + d.rBase + 0.6))
        return Frame(tab: tab, closed: Vector2D(-m.x, -m.y),
                     across: m.x != 0 ? Vector2D(0, 1) : Vector2D(1, 0))
    }

    /// The slot face, as a `w` coordinate.
    func slotFace(_ design: LiddedBinDesign) -> Double {
        let m = design.lidDirection
        let size = m.x != 0 ? design.gridY : design.gridX
        return size * design.d.lGrid / 2 - 0.25 - design.fit.wallThickness
    }

    /// Mid thickness of the lid's plate.
    func plateMid(_ design: LiddedBinDesign) -> Double {
        design.storageHeight + design.d.hBase - design.fit.vPosTolerance - design.fit.thickness / 2
    }

    /// The bump's flat top centre, as an `a` coordinate.
    func flatCentre(_ design: LiddedBinDesign) -> Double {
        let stop = design.fit.detentProtrusion / Foundation.tan(LidFit.detentStopAngle * .pi / 180)
        return 0.9 - stop - LidFit.detentFlatLength / 2
    }

    /// A box around both detents at the closed end, 16 mm along the slide direction.
    func detentRegion(_ design: LiddedBinDesign) -> any Geometry3D {
        let f = frame(design)
        let size = Vector3D(f.closed.x != 0 ? 16 : 100, f.closed.y != 0 ? 16 : 100, 6)
        let centre = f.point(a: 0, w: 0, z: plateMid(design))
        return Box(size).aligned(at: .center).translated(centre)
    }

    /// Bin and lid overlap near the detents, with the lid moved `shift` mm toward open.
    func detentOverlap(_ design: LiddedBinDesign, shift: Double = 0) async throws -> Double {
        let region = detentRegion(design)
        let m = design.lidDirection
        let bin = design.binSolid(pockets: design.pockets()).intersecting { region }
        let lid = design.lidBody().translated(x: m.x * shift, y: m.y * shift).intersecting { region }
        return try await measure(bin.intersecting { lid }).volume
    }

    /// How far the plate edge has to give way to let the bump pass, at mid plate thickness on the
    /// +w wall, with the lid moved `shift` mm toward open: across the slide direction, the longest
    /// overlap of the bin and the lid along rays at `a` from -1.2 to 1.2 in 0.01 mm steps. (The lid is
    /// moved by casting its rays from the point that moves onto the ray's start.)
    func deflections(_ design: LiddedBinDesign, shifts: [Double]) async throws -> [Double] {
        let f = frame(design)
        let m = design.lidDirection
        let z = plateMid(design)
        let bin = design.binSolid(pockets: design.pockets()), lid = design.lidBody()
        return try await ModelFileGenerator.evaluate { evaluator in
            func intervals(_ g: any Geometry3D, _ origin: Vector3D) async -> [(Double, Double)] {
                // A ray that starts inside `g` (its first crossing exits) has an interval from the origin
                var result: [(Double, Double)] = [], entry: Double? = 30
                for hit in await evaluator.surfaces(of: g, from: origin, in: f.alongAcross) {
                    let w = f.w(hit.position) - f.w(origin) + 30
                    if hit.transition == .entering { entry = w }
                    else if let e = entry { result.append((e, w)); entry = nil }
                }
                return result
            }
            var binRays: [[(Double, Double)]] = []
            let positions = (0...240).map { -1.2 + Double($0) * 0.01 }
            for a in positions { binRays.append(await intervals(bin, f.point(a: a, w: 30, z: z))) }
            var result: [Double] = []
            for shift in shifts {
                var deepest = 0.0
                for (k, a) in positions.enumerated() {
                    let origin = f.point(a: a, w: 30, z: z) - Vector3D(m.x * shift, m.y * shift, 0)
                    for l in await intervals(lid, origin) {
                        for b in binRays[k] {
                            deepest = max(deepest, min(l.1, b.1) - max(l.0, b.0))
                        }
                    }
                }
                result.append(deepest)
            }
            return result
        }
    }

    /// The plate edge overlap: the lid's plate edge at the middle of the bin less the bump's face
    /// on its flat top, both across the slide direction at mid plate thickness. The plate edge is
    /// straight along the slide direction, so this is the overlap as the edge slides past.
    func plateOverlap(_ design: LiddedBinDesign, at a: Double? = nil) async throws -> (overlap: Double, bump: Double, edge: Double) {
        let f = frame(design)
        let z = plateMid(design)
        let bin = design.binSolid(pockets: design.pockets()), lid = design.lidBody()
        return try await ModelFileGenerator.evaluate { evaluator in
            let bump = await evaluator.surfaces(of: bin, from: f.point(a: a ?? flatCentre(design), w: 0, z: z),
                                                in: f.alongAcross)
                .first { $0.transition == .entering }.map { f.w($0.position) } ?? .nan
            let edge = await evaluator.surfaces(of: lid, from: Vector3D(0, 0, z), in: f.alongAcross)
                .last { $0.transition == .exiting }.map { f.w($0.position) } ?? .nan
            return (edge - bump, bump, edge)
        }
    }

    /// The bump's two faces in plan view at mid plate thickness, from rays along the slide
    /// direction (toward the closed end) at two depths into the slot. The ramp is the face the
    /// ray enters first, the stop face the one it leaves by.
    struct Faces {
        var rampAngle: Double, stopAngle: Double
        /// The bump's length along the slide direction at the slot face depth `w1`.
        var ramp1: Double, stop1: Double
    }

    func faces(_ design: LiddedBinDesign, depths: (Double, Double) = (0.15, 0.35)) async throws -> Faces {
        let f = frame(design)
        let z = plateMid(design)
        let slot = slotFace(design)
        let bin = design.binSolid(pockets: design.pockets())
        return try await ModelFileGenerator.evaluate { evaluator in
            func cross(_ depth: Double) async -> (ramp: Double, stop: Double) {
                let hits = await evaluator.surfaces(of: bin, from: f.point(a: -10, w: slot - depth, z: z),
                                                    in: f.alongClosed)
                let enter = hits.firstIndex { $0.transition == .entering }
                guard let enter, let exit = hits[enter...].firstIndex(where: { $0.transition == .exiting })
                else { return (.nan, .nan) }
                return (f.a(hits[enter].position), f.a(hits[exit].position))
            }
            let c1 = await cross(depths.0), c2 = await cross(depths.1)
            let dw = depths.1 - depths.0
            let ramp = Foundation.atan(dw / (c2.ramp - c1.ramp)) * 180 / .pi
            let stop = Foundation.atan(dw / (c1.stop - c2.stop)) * 180 / .pi
            return Faces(rampAngle: ramp, stopAngle: stop, ramp1: c1.ramp, stop1: c1.stop)
        }
    }

    /// The closed lid's seat around the bump: across the slide direction on the flat top (bump
    /// face to notch face), and along it at mid bump depth on the ramp and the stop face.
    struct Seat { var depth: Double, ramp: Double, stop: Double }

    func seat(_ design: LiddedBinDesign) async throws -> Seat {
        let f = frame(design)
        let z = plateMid(design)
        let slot = slotFace(design)
        let bin = design.binSolid(pockets: design.pockets()), lid = design.lidBody()
        let w = slot - (design.fit.detentProtrusion + design.fit.sideClearance) / 2
        return try await ModelFileGenerator.evaluate { evaluator in
            let origin = f.point(a: flatCentre(design), w: 0, z: z)
            let bump = await evaluator.surfaces(of: bin, from: origin, in: f.alongAcross)
                .first { $0.transition == .entering }.map { f.w($0.position) } ?? .nan
            let notch = await evaluator.surfaces(of: lid, from: origin, in: f.alongAcross)
                .last { $0.transition == .exiting && f.w($0.position) < bump }.map { f.w($0.position) } ?? .nan

            let start = f.point(a: -6, w: w, z: z)
            let b = await evaluator.surfaces(of: bin, from: start, in: f.alongClosed).map { ($0.transition, f.a($0.position)) }
            let l = await evaluator.surfaces(of: lid, from: start, in: f.alongClosed).map { ($0.transition, f.a($0.position)) }
            guard let binIn = b.first(where: { $0.0 == .entering })?.1,
                  let binOut = b.first(where: { $0.0 == .exiting && $0.1 > binIn })?.1,
                  let lidOut = l.first(where: { $0.0 == .exiting })?.1,
                  let lidIn = l.first(where: { $0.0 == .entering && $0.1 > lidOut })?.1
            else { return Seat(depth: bump - notch, ramp: .nan, stop: .nan) }
            return Seat(depth: bump - notch, ramp: binIn - lidOut, stop: lidIn - binOut)
        }
    }

    @Test(arguments: [(0.15, 0.20), (0.25, 0.20), (0.15, 0.45), (0.25, 0.45)])
    func `the bump overlaps the plate edge by the detent interference`(interference: Double, clearance: Double) async throws {
        let d = seated { $0.detentInterference = interference; $0.lidClearance = clearance }
        let o = try await plateOverlap(d)
        print("detent overlap, interference \(interference) clearance \(clearance): \(o.overlap) (bump \(o.bump), edge \(o.edge))")
        #expect(abs(d.fit.detentProtrusion - (clearance + interference)) < 1e-9)
        #expect(abs(o.overlap - interference) < 0.01, "overlap \(o.overlap)")
    }

    @Test(arguments: LidOrientation.allCases)
    func `the closed lid seats on the bump`(direction: LidOrientation) async throws {
        let d = seated { $0.lidOrientation = direction }
        let volume = try await detentOverlap(d)
        let s = try await seat(d)
        let faces = try await faces(d)
        let clearance = LidFit.detentSeatClearance
        let rampGap = clearance / Foundation.sin(LidFit.detentRampAngle * .pi / 180)
        let stopGap = clearance / Foundation.sin(LidFit.detentStopAngle * .pi / 180)
        print("seat \(direction): overlap \(volume) mm^3, depth gap \(s.depth), ramp gap \(s.ramp) (\(rampGap)), stop gap \(s.stop) (\(stopGap)), ramp \(faces.rampAngle), stop \(faces.stopAngle)")
        #expect(volume < 0.05, "\(direction) overlap \(volume)")
        #expect(abs(s.depth - clearance) < 0.01, "\(direction) depth gap \(s.depth)")
        #expect(abs(s.ramp - rampGap) < 0.01, "\(direction) ramp gap \(s.ramp)")
        #expect(abs(s.stop - stopGap) < 0.01, "\(direction) stop gap \(s.stop)")
        #expect(abs(faces.rampAngle - LidFit.detentRampAngle) < 1, "\(direction) ramp \(faces.rampAngle)")
        #expect(abs(faces.stopAngle - LidFit.detentStopAngle) < 1, "\(direction) stop \(faces.stopAngle)")
    }

    @Test func `the original detent is unchanged`() async throws {
        let d = design()
        #expect(d.fit.detentStyle == .original)
        #expect(LiddedBinConfiguration.openSCADOriginal.detentInterference == 0.15)
        #expect(LiddedBinConfiguration().detentStyle == .seated)
        #expect(LiddedBinConfiguration().detentInterference == 0.25)
        let volume = try await measure(d.binSolid(pockets: d.pockets()).intersecting { d.lidBody() }).volume
        let region = try await detentOverlap(d)
        print("original preset: closed overlap \(volume) mm^3, near the detents \(region) mm^3")
        #expect(abs(volume - 1.392) < 0.01)
        // The original bump face is 0.6 into the slot and the notch 0.45 deeper
        let o = try await plateOverlap(d, at: 0)
        #expect(abs(slotFace(d) - o.bump - 0.6) < 0.01, "bump \(o.bump)")
    }

    @Test func `opening pushes the lid over the stop face`() async throws {
        let d = seated()
        let faces = try await faces(d)
        let p = d.fit.detentProtrusion
        let length = p / Foundation.tan(LidFit.detentRampAngle * .pi / 180) + LidFit.detentFlatLength
            + p / Foundation.tan(LidFit.detentStopAngle * .pi / 180)
        print("bump faces: ramp \(faces.rampAngle) deg, stop \(faces.stopAngle) deg, length \(length) mm")
        #expect(abs(faces.rampAngle - LidFit.detentRampAngle) < 1, "ramp \(faces.rampAngle)")
        #expect(abs(faces.stopAngle - LidFit.detentStopAngle) < 1, "stop \(faces.stopAngle)")
        // The ramp faces the open end and the stop face the closed end
        #expect(faces.ramp1 < faces.stop1)

        var sweep: [(Double, Double)] = []
        for i in 0...24 {
            let s = Double(i) * 0.25
            sweep.append((s, try await detentOverlap(d, shift: s)))
        }
        print("slide sweep (shift mm, overlap mm^3):")
        for (s, v) in sweep { print(String(format: "  %.2f  %.4f", s, v)) }
        let none = 0.01
        let peak = sweep.max { $0.1 < $1.1 }!
        print("peak \(peak.1) mm^3 at \(peak.0) mm")
        #expect(sweep[0].1 < 0.05)
        #expect(peak.1 > 0.2)
        #expect(sweep.last!.1 < none)
        let peakIndex = sweep.firstIndex { $0.0 == peak.0 }!
        #expect(sweep[peakIndex...].contains { $0.1 < none })

        // The asymmetry is in how fast the plate edge has to give way. Opening, the notch's stop
        // face climbs the bump's stop face: the deflection reaches the full interference within a
        // short slide. It falls back to 0 as the lid's corner runs down the ramp, which is where
        // a closing lid meets the bump first. Rise: from the last shift with no deflection to the
        // first with 95% of the largest deflection. Fall: from the last with 95% to the first with none.
        let i = d.fit.detentInterference
        let shifts = (0...50).map { Double($0) * 0.05 }
        let deflections = Array(zip(shifts, try await self.deflections(d, shifts: shifts)))
        print("deflection sweep (shift mm, deflection mm):")
        for (s, v) in deflections { print(String(format: "  %.2f  %.4f", s, v)) }
        let most = 0.95 * deflections.map(\.1).max()!
        let full = try #require(deflections.firstIndex { $0.1 >= most })
        let lastFull = try #require(deflections.lastIndex { $0.1 >= most })
        let start = try #require(deflections[..<full].lastIndex { $0.1 < 1e-6 })
        let end = try #require(deflections[lastFull...].firstIndex { $0.1 < 1e-6 })
        let rise = deflections[full].0 - deflections[start].0
        let fall = deflections[end].0 - deflections[lastFull].0
        print("deflection rises to \(deflections[full].1) over \(rise) mm (from \(deflections[start].0)), falls from \(deflections[lastFull].0) to 0 over \(fall) mm")
        // The bump sits where the plate edge starts to curve into its corner, so the deepest
        // overlap while sliding is a little less than the interference measured on the straight edge
        #expect(deflections.map(\.1).max()! > 0.9 * i && deflections.map(\.1).max()! < i + 0.01)
        #expect(rise < fall, "rise \(rise) fall \(fall)")
    }
}
