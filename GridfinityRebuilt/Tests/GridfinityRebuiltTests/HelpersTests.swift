import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct HelpersTests {
    @Test func `hole and baseplate constants match standard.scad`() {
        let d = Dimensions.standard
        #expect(d.rHole1 == 1.5 && d.rHole2 == 3.25 && d.dHole == 26)
        #expect(d.dHoleFromSide == 8 && d.hHole == 2.4 && d.hSlit == 0.2)
        let b = BaseplateDimensions.standard
        #expect(b.bpHBot == 6.4 && b.bpCutSize == 21.4 && b.bpCutDepth == 4)
        #expect(b.bpRcutWidth == 8.5 && b.bpRcutLength == 4.25 && b.bpRcutDepth == 2)
        #expect(b.bpXYClearance == 0.5 && b.dCs == 2.5 && b.rSkel == 2)
        #expect(b.rCb == 2.75 && b.hCb == 3 && b.hSkel == 1)
    }

    @Test func `clamp matches clp`() {
        #expect(clamp(5, 0, 3) == 3 && clamp(-1, 0, 3) == 0 && clamp(2, 0, 3) == 2)
    }

    @Test func `patternCircular rotates four copies`() async throws {
        let cell = Box([2, 1, 1]).translated(x: 10)
        let m = try await measure(patternCircular(count: 4, cell))
        #expect(abs(m.volume - 8) < 1e-9)
        #expect(abs(m.min.x + 12) < 1e-6 && abs(m.max.x - 12) < 1e-6)
        #expect(abs(m.min.y + 12) < 1e-6 && abs(m.max.y - 12) < 1e-6)
    }

    @Test func `copyMirror adds the mirror image`() async throws {
        let m = try await measure(copyMirror(Box([2, 1, 1]).translated(x: 1, y: 3), along: .y))
        #expect(abs(m.volume - 4) < 1e-9)
        #expect(abs(m.min.y + 4) < 1e-6 && abs(m.max.y - 4) < 1e-6)
    }

    @Test func `fractional patternLinear keeps the original centering quirk`() async throws {
        // Measured with OpenSCAD 2026.10: pattern_linear(1.5, 1, 10, 10) cube(1)
        // has x bounds [-2.5, 8.5] (two copies) and y bounds [0, 1].
        let m = try await measure(patternLinear(x: 1.5, y: 1, spacingX: 10, Box([1, 1, 1])))
        #expect(abs(m.min.x + 2.5) < 1e-6 && abs(m.max.x - 8.5) < 1e-6)
        #expect(abs(m.min.y) < 1e-6 && abs(m.max.y - 1) < 1e-6)
        #expect(abs(m.volume - 2) < 1e-9)
    }

    @Test func `patternLinear with a count of zero or less gives no copies as OpenSCAD does`() async throws {
        // OpenSCAD 2026.10 reports "top level object is empty" for pattern_linear(0, ...)
        // and pattern_linear(-1, ...): the reversed range [1:0] yields no iterations.
        for x in [0.0, -1.0] {
            let m = try await measure(patternLinear(x: x, y: 1, spacingX: 10, Box([1, 1, 1])))
            #expect(m.volume == 0)
        }
    }
}
