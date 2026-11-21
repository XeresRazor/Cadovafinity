import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct BaseTests {
    let refs = ReferenceSet.containing()
    let d = Dimensions.standard

    @Test func `1x1 base without holes matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_1x1_style0", d.gridfinityBase(gridX: 1, gridY: 1, styleHole: 0), references: refs)
    }

    @Test func `2x1 base with magnet holes matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_2x1_style1", d.gridfinityBase(gridX: 2, gridY: 1, styleHole: 1), references: refs)
    }

    @Test func `2x2 base with magnet and screw holes matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_2x2_style2", d.gridfinityBase(gridX: 2, gridY: 2, styleHole: 2), references: refs)
    }

    @Test func `1x1 base with slit holes matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_1x1_style3", d.gridfinityBase(gridX: 1, gridY: 1, styleHole: 3), references: refs)
    }

    @Test func `1x1 base with refined holes matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_1x1_style4", d.gridfinityBase(gridX: 1, gridY: 1, styleHole: 4), references: refs)
    }

    @Test func `2x2 base with corner holes only matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "base_2x2_corners", d.gridfinityBase(gridX: 2, gridY: 2, styleHole: 2, onlyCorners: true), references: refs
        )
    }

    @Test func `2x2 baseplate cutter matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "base_2x2_baseplate",
            d.gridfinityBase(gridX: 2, gridY: 2, divisionX: 1, divisionY: 1, styleHole: 0, offset: 0.5, finalCut: false),
            references: refs
        )
    }

    @Test func `1.5x1 base with half cells matches OpenSCAD`() async throws {
        try await expectMatchesReference("base_1_5x1_half", d.gridfinityBase(gridX: 1.5, gridY: 1, styleHole: 0), references: refs)
    }

    @Test func `1x1 base with negative offset matches OpenSCAD`() async throws {
        try await expectMatchesReference(
            "base_1x1_offset_neg", d.gridfinityBase(gridX: 1, gridY: 1, styleHole: 2, offset: -1.2), references: refs
        )
    }

    @Test func `final cut adds the top block and its absence leaves the feet unclipped`() async throws {
        let withCut = try await measure(d.gridfinityBase(gridX: 2, gridY: 1, styleHole: 1))
        #expect(abs(withCut.max.z - (d.hBase + d.hBot / 1.5)) < 0.01)

        // Without the final cut there is no top block and no clip: the feet keep their full
        // upper section, which an offset of 0.5 makes hBot / 2 + 10 * 0.5 tall; block_base_solid's
        // outer mirror moves it down by its oo shift, (0.5 / 2) * (sqrt 2 - 1).
        let plate = try await measure(
            d.gridfinityBase(gridX: 2, gridY: 2, divisionX: 1, divisionY: 1, styleHole: 0, offset: 0.5, finalCut: false)
        )
        let foot = try await measure(d.blockBaseSolid(offset: 0.5))
        #expect(abs(plate.max.z - foot.max.z) < 0.001)
        #expect(abs(plate.max.z - (d.hBase - 0.25 * (2.0.squareRoot() - 1) + d.hBot / 2 + 5)) < 0.001)
    }

    @Test func `sub-division counts follow the first integer multiple`() {
        #expect(d.baseSubdivisions(1) == 1)
        #expect(d.baseSubdivisions(2) == 1)
        #expect(d.baseSubdivisions(3) == 1)
        #expect(d.baseSubdivisions(1.5) == 2)
        #expect(d.baseSubdivisions(1.25) == 4)
        #expect(d.baseSubdivisions(1.0005) == 1)
        // 1.504 * 2 = 3.008 is 0.008 from an integer, outside the 0.001 window, and no other
        // multiple up to 5 is closer, so OpenSCAD falls back to one sub-division.
        #expect(d.baseSubdivisions(1.504) == 1)
        #expect(d.baseSubdivisions(1.5, division: 1) == 1)
    }
}
