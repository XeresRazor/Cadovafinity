import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// The Flush raised interior style, which lid-bin.scad does not have (so there is no OpenSCAD
/// reference): the floor inside the walls is one flat surface at `flushFloorHeight`, and nothing
/// else of the bin changes.
struct FlushRaisedTests {
    /// The production lid fit with `cornerSegments = 16`.
    static func design(_ style: InteriorStyle, _ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        c.interiorStyle = style
        edit(&c)
        return LiddedBinDesign(c)
    }

    struct Case: CustomTestStringConvertible, Sendable {
        var name: String
        var edit: @Sendable (inout LiddedBinConfiguration) -> Void
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "2x2x3, 2 by 1") { $0.divX = 2; $0.divY = 1 },
        Case(name: "1x1x3, 1 by 1") { $0.gridX = 1; $0.gridY = 1; $0.divX = 1; $0.divY = 1 },
        Case(name: "2x2x3, 6 by 6") { _ in },
        Case(name: "3x2x3 two sizes, 3 by 3") {
            $0.gridX = 3; $0.compartmentPattern = .multiSize; $0.divX = 3; $0.divY = 3
        },
    ]

    /// The heights of the floor at a grid of points over every compartment: rays cast down from
    /// just under the pocket top. Points within `margin` of a pocket's edge (the dividers, the
    /// ring at the wall and the lid slot above it) or of the rounded corners of the interior are
    /// left out.
    func floorHeights(_ d: LiddedBinDesign, step: Double = 1.5, margin: Double = 1) async throws -> [Double] {
        let solid = d.binSolid(pockets: d.pockets()).withSegmentation(count: 64)
        let pockets = try #require(d.pockets()).withSegmentation(count: 64)
        let footprint = d.interiorFootprint(height: 1)
        let radius = d.d.rBase
        let start = d.pocketTop - 0.5
        return try await ModelFileGenerator.evaluate { evaluator in
            let interior = await evaluator.bounds(of: footprint)!
            let half = (interior.maximum - interior.minimum) / 2
            /// Inside the interior's rounded rectangle shrunk by the margin.
            func inInterior(_ x: Double, _ y: Double) -> Bool {
                let hx = half.x - margin, hy = half.y - margin, r = radius - margin
                let ax = abs(x), ay = abs(y)
                guard ax <= hx, ay <= hy else { return false }
                let cx = hx - r, cy = hy - r
                guard ax > cx, ay > cy else { return true }
                return (ax - cx) * (ax - cx) + (ay - cy) * (ay - cy) <= r * r
            }
            var heights: [Double] = []
            for pocket in await evaluator.components(of: pockets) {
                let b = await evaluator.bounds(of: pocket)!
                var x = b.minimum.x + margin
                while x <= b.maximum.x - margin {
                    var y = b.minimum.y + margin
                    while y <= b.maximum.y - margin {
                        if inInterior(x, y) {
                            let hit = await evaluator.surfaces(of: solid, from: Vector3D(x, y, start), in: .negativeZ)
                                .first { $0.transition == .entering }
                            heights.append(hit?.position.z ?? .nan)
                        }
                        y += step
                    }
                    x += step
                }
            }
            return heights
        }
    }

    @Test func `the flush floor height is the top of the base feet`() {
        let d = Self.design(.flushRaised)
        #expect(d.flushFloorHeight == d.d.hBase + d.d.hBot / 2)
        #expect(abs(d.flushFloorHeight - 6.1) < 1e-12)
        #expect(d.effectiveInteriorStyle == .flushRaised)
        #expect(d.pocketFloor == d.flushFloorHeight)
        // The other styles keep the pocket floor of lid-bin.scad, the wall line
        #expect(Self.design(.minimal).pocketFloor == d.d.dWall)
        #expect(Self.design(.partialRaised).pocketFloor == d.d.dWall)
    }

    @Test(arguments: cases)
    func `the flush floor is flat at the flush floor height`(_ c: Case) async throws {
        let d = Self.design(.flushRaised, c.edit)
        let heights = try await floorHeights(d)
        #expect(heights.count > 100, "\(c.name): \(heights.count) points")
        let off = heights.filter { !(abs($0 - d.flushFloorHeight) < 1e-3) }
        #expect(off.isEmpty, "\(c.name): \(off.count) of \(heights.count) points off the floor, \(off.prefix(10))")
        print("flush floor \(c.name): \(heights.count) points, \(heights.min() ?? .nan) to \(heights.max() ?? .nan)")
    }

    @Test(arguments: [InteriorStyle.minimal, .partialRaised], [cases[0], cases[1]])
    func `the floors of the other styles are not flat`(_ style: InteriorStyle, _ c: Case) async throws {
        // The same probe finds the recesses, so the flatness test can fail
        let d = Self.design(style, c.edit)
        let heights = try await floorHeights(d)
        let spread = heights.max()! - heights.min()!
        let below = d.flushFloorHeight - heights.min()!
        print("\(style) \(c.name): floor from \(heights.min()!) to \(heights.max()!)")
        #expect(below > 1, "\(style) \(c.name): lowest point \(below) under the flush floor height")
        // The 1x1 partially raised compartment lies inside one recess, flat at 4.9 mm except
        // for the slope at its edge (up to 5.31 mm within the 1 mm margin)
        let minimumSpread = style == .partialRaised && c.name.hasPrefix("1x1") ? 0.3 : 0.5
        #expect(spread > minimumSpread, "\(style) \(c.name): spread \(spread)")
    }

    struct Volumes { var minimal: Double, partial: Double, flush: Double }

    @Test(arguments: [cases[0], cases[1], cases[3]])
    func `flush raised fills the recesses and changes nothing above the floor`(_ c: Case) async throws {
        let minimal = Self.design(.minimal, c.edit), flush = Self.design(.flushRaised, c.edit)
        let partial = Self.design(.partialRaised, c.edit)
        let m = try await measure(minimal.binSolid(pockets: minimal.pockets()))
        let p = try await measure(partial.binSolid(pockets: partial.pockets()))
        let f = try await measure(flush.binSolid(pockets: flush.pockets()))
        print("volumes \(c.name): minimal \(m.volume) partial \(p.volume) flush \(f.volume); filled \(f.volume - m.volume) over minimal, \(f.volume - p.volume) over partial")
        #expect(f.volume > p.volume + 100 && p.volume > m.volume + 100, "\(c.name)")
        // The outer shape is unchanged
        for (a, b) in [(f.min, m.min), (f.max, m.max), (f.min, p.min), (f.max, p.max)] {
            #expect((a - b).magnitude < 1e-6, "\(c.name): \(a) vs \(b)")
        }
        // The flush bin is the minimal bin plus material below the flush floor only: the minimal
        // bin lies inside it, and above the floor the two are the same
        let fs = flush.binSolid(pockets: flush.pockets()), ms = minimal.binSolid(pockets: minimal.pockets())
        let above = Box(x: 400, y: 400, z: 200).aligned(at: .centerXY).translated(z: flush.flushFloorHeight)
        // The wall and the lip: above the floor, outside the interior
        let outside = above.subtracting { flush.interiorFootprint(height: 200) }
        let (removed, addedAbove, wallFlush, wallMinimal, lidFlush, lidMinimal) = try await ModelFileGenerator.evaluate { e in
            (await e.measurements(of: ms.subtracting { fs }.withSegmentation(count: 64)).volume,
             await e.measurements(of: fs.subtracting { ms }.intersecting { above }.withSegmentation(count: 64)).volume,
             await e.measurements(of: fs.intersecting { outside }.withSegmentation(count: 64)).volume,
             await e.measurements(of: ms.intersecting { outside }.withSegmentation(count: 64)).volume,
             await e.measurements(of: flush.lidBody().withSegmentation(count: 64)).volume,
             await e.measurements(of: minimal.lidBody().withSegmentation(count: 64)).volume)
        }
        #expect(abs(removed) < 1e-6, "\(c.name): minimal minus flush \(removed)")
        #expect(abs(addedAbove) < 1e-6, "\(c.name): flush minus minimal above the floor \(addedAbove)")
        #expect(wallFlush > 1000 && abs(wallFlush - wallMinimal) < 1e-6, "\(c.name): wall \(wallFlush) vs \(wallMinimal)")
        #expect(abs(lidFlush - lidMinimal) < 1e-9, "\(c.name): lid \(lidFlush) vs \(lidMinimal)")
    }

    @Test func `the pockets start at the flush floor and end at the pocket top`() async throws {
        let d = Self.design(.flushRaised) { $0.divX = 2; $0.divY = 1 }
        let pockets = try await measure(try #require(d.pockets()))
        #expect(abs(pockets.min.z - d.flushFloorHeight) < 1e-6)
        #expect(abs(pockets.max.z - (d.pocketTop + 0.001)) < 1e-6)
        // The pocket top is 0.1 mm (the vertical fit tolerance) under the lid's plate
        #expect(abs(d.lidPlateZ - d.pocketTop - d.fit.vFitTolerance) < 1e-9)
        // The pocket top is the same in every style, so the depth is the pocket top less the
        // flush floor (13.7 mm for 3 units)
        let minimal = try await measure(try #require(Self.design(.minimal) { $0.divX = 2; $0.divY = 1 }.pockets()))
        #expect(abs(minimal.max.z - pockets.max.z) < 1e-9)
        #expect(abs((pockets.max.z - pockets.min.z) - (d.pocketTop - d.flushFloorHeight + 0.001)) < 1e-6)
        #expect(abs(d.pocketTop - d.flushFloorHeight - 13.7) < 1e-9)
    }

    /// Flush raised needs 2 mm from the flush floor to the pocket top. The 1 unit bin (pocket top
    /// 5.8 mm, under the 6.1 mm floor) is built as Partially raised; from 2 units on the floor is flush.
    /// The customizer's shortest bin is 2 units, so this fallback is only reachable through the model API.
    @Test func `a bin too short for the flush floor is built partially raised`() async throws {
        let depths: [(Double, Double)] = [(1, -0.3), (2, 6.7), (3, 13.7)]
        for (units, depth) in depths {
            let d = Self.design(.flushRaised) { $0.gridZ = units }
            #expect(abs(d.pocketTop - d.flushFloorHeight - depth) < 1e-9, "\(units) units")
            #expect(d.effectiveInteriorStyle == (units == 1 ? .partialRaised : .flushRaised), "\(units) units")
        }
        // The threshold is a storage height of 4.3 mm
        #expect(Self.design(.flushRaised) { $0.gridZ = (4.31 + 5) / 7 }.effectiveInteriorStyle == .flushRaised)
        #expect(Self.design(.flushRaised) { $0.gridZ = (4.29 + 5) / 7 }.effectiveInteriorStyle == .partialRaised)
        // The fallback is a safeguard for the model API: every bin the customizer offers is flush with
        // at least 2 mm of depth
        var heights: [(HeightMode, Double)] = Array(Int(LiddedBinLimits.unitsHeight.lowerBound)...Int(LiddedBinLimits.unitsHeight.upperBound))
            .map { (.units, Double($0)) }
        heights += [(.internalMillimeters, LiddedBinLimits.internalHeight.lowerBound),
                    (.externalMillimeters, LiddedBinLimits.externalHeight.lowerBound)]
        for (mode, z) in heights {
            let d = Self.design(.flushRaised) { $0.heightMode = mode; $0.gridZ = z }
            #expect(d.effectiveInteriorStyle == .flushRaised, "\(mode) \(z)")
            #expect(d.pocketTop - d.pocketFloor >= LiddedBinDesign.minimumFlushDepth, "\(mode) \(z)")
        }

        // The smallest bin builds, as the partially raised bin
        let small: (inout LiddedBinConfiguration) -> Void = { $0.gridZ = 1; $0.divX = 2; $0.divY = 1 }
        let flush = Self.design(.flushRaised, small), partial = Self.design(.partialRaised, small)
        let fs = flush.binSolid(pockets: flush.pockets()), ps = partial.binSolid(pockets: partial.pockets())
        let (volume, difference) = try await ModelFileGenerator.evaluate { e in
            (await e.measurements(of: fs.withSegmentation(count: 64)).volume,
             await e.measurements(of: Union { fs.subtracting { ps }; ps.subtracting { fs } }.withSegmentation(count: 64)).volume)
        }
        #expect(volume > 1000)
        #expect(abs(difference) < 1e-6, "\(difference)")
        let pockets = try await measure(try #require(flush.pockets()))
        #expect(pockets.max.z - pockets.min.z > 0)

        // The smallest flush bin, 2 units, has compartments 6.7 mm deep over a flat floor
        let two = Self.design(.flushRaised) { $0.gridZ = 2; $0.divX = 2; $0.divY = 1 }
        let twoPockets = try await measure(try #require(two.pockets()))
        #expect(abs(twoPockets.min.z - two.flushFloorHeight) < 1e-6)
        #expect(abs(twoPockets.max.z - twoPockets.min.z - 6.701) < 1e-6)
        let heightsTwo = try await floorHeights(two)
        #expect(!heightsTwo.isEmpty && heightsTwo.allSatisfy { abs($0 - two.flushFloorHeight) < 1e-3 })
    }
}
