import Foundation
import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct HoleTests {
    let refs = ReferenceSet.containing()
    let d = Dimensions.standard

    @Test func `style 1 matches OpenSCAD`() async throws {
        try await expectMatchesReference("hole_style1", d.blockBaseHole(style: 1), references: refs)
    }

    @Test func `style 2 matches OpenSCAD`() async throws {
        try await expectMatchesReference("hole_style2", d.blockBaseHole(style: 2), references: refs)
    }

    @Test func `style 3 matches OpenSCAD`() async throws {
        try await expectMatchesReference("hole_style3", d.blockBaseHole(style: 3), references: refs)
    }

    @Test func `style 2 with offset matches OpenSCAD`() async throws {
        try await expectMatchesReference("hole_style2_off", d.blockBaseHole(style: 2, offset: -0.5), references: refs)
    }

    @Test func `refined hole matches OpenSCAD`() async throws {
        try await expectMatchesReference("hole_refined", d.refinedHole(), references: refs)
    }

    @Test func `style 1 is a single centered cylinder`() async throws {
        let m = try await measure(d.blockBaseHole(style: 1))
        let ideal64 = 0.5 * 64 * Foundation.sin(2 * Double.pi / 64) * d.rHole2 * d.rHole2 * 2 * d.hHole
        #expect(abs(m.volume - ideal64) / ideal64 < 0.01)
        #expect(abs(m.min.z + d.hHole) < 0.01 && abs(m.max.z - d.hHole) < 0.01)
    }

    @Test func `style 3 slit removes magnet material above the slit plane`() async throws {
        let s3 = try await measure(d.blockBaseHole(style: 3))
        let s2 = try await measure(d.blockBaseHole(style: 2))
        // Style 3 raises the magnet by hSlit but the slit boxes trim it back to a flat-sided shape,
        // so it differs from style 2 and stays within the screw cylinder height.
        #expect(abs(s3.volume - s2.volume) > 1)
        #expect(s3.max.z <= d.hBase + 0.01)
    }
}
