import Testing
import Cadova
import GridfinityRebuilt  // Deliberately not @testable: checks the API is really public.

struct PublicAPITests {
    @Test func `primitives are reachable without testable`() {
        let d = Dimensions.standard
        let profile = d.wallProfile(height: 16)
        let results: [Any?] = [
            d.blockWall(gridX: 1, gridY: 1, length: 42, profile: profile),
            d.blockBottom(height: 2.2, gridX: 1, gridY: 1, length: 42),
            d.blockBaseSolid(nx: 1, ny: 1, length: 42, offset: 0),
            profile,
            d.lipelessWallProfile(height: 16),
            d.baseProfile(),
            roundedRectangle(length: 10, width: 8, height: 2, radius: 1),
            roundedRectangle2D(length: 10, width: 8, radius: 1),
            sweepRounded(width: 10, height: 8, profile: d.baseProfile()),
        ]
        #expect(results.count == 9)
        #expect(results.allSatisfy { $0 != nil })
    }
}
