import Testing
@testable import GridfinityRebuilt

struct DimensionsTests {
    @Test func `standard constants match standard.scad`() {
        let d = Dimensions.standard
        #expect(d.hBase == 5)
        #expect(d.rBase == 4)
        #expect(d.rC1 == 0.8)
        #expect(d.rC2 == 2.4)
        #expect(d.hBot == 2.2)
        #expect(d.rFo1 == 8.5)
        #expect(d.rFo2 == 3.2)
        #expect(d.rFo3 == 1.6)
        #expect(d.lGrid == 42)
        #expect(d.dDiv == 1.2)
        #expect(d.dWall == 0.95)
        #expect(d.dClear == 0.25)
        #expect(d.hLip == 3.548)
        #expect(d.rF1 == 0.6)
    }

    @Test func `derived values`() {
        let d = Dimensions.standard
        #expect(abs(d.dWall2 - (4 - 0.8 - 0.25 * 2.0.squareRoot())) < 1e-12)
        #expect(abs(d.dMagic - -1.2) < 1e-12)
    }

    @Test func `wall thickness override changes dMagic only`() {
        var d = Dimensions.standard
        d.dWall = 1.6
        #expect(abs(d.dMagic - (-0.5 - 3.2 + 1.2)) < 1e-12)
        #expect(d.dWall2 == Dimensions.standard.dWall2)
    }
}
