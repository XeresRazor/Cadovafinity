import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct BinGeometryTests {
    let refs = ReferenceSet.containing()
    @Test func `regular 2x1x3 shell matches OpenSCAD`() async throws {
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16)
        try await expectMatchesReference("init_2x1x3", bin.shell(cornerSegments: 16), references: refs, volumeTolerance: 1e-4)
    }

    @Test func `regular 2x1x3 shell at dWall 1.6 matches OpenSCAD`() async throws {
        var wide = Dimensions.standard
        wide.dWall = 1.6
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16, dimensions: wide)
        try await expectMatchesReference("init_2x1x3_dw16", bin.shell(cornerSegments: 16), references: refs, volumeTolerance: 1e-4)
    }

    @Test func `cut_move at dWall 1.6 uses the shifted d_magic`() async throws {
        var wide = Dimensions.standard
        wide.dWall = 1.6
        let bin = BinGeometry(gridX: 3, gridY: 2, height: 16, dimensions: wide)
        let marker = Box([1, 1, 1]).aligned(at: .centerXY)
        let actual = try await measure(bin.placed(x: 1, y: 0, w: 1, h: 1, marker))
        let problems = compare(actual, try ReferenceSet.containing().metrics("cut_move_marker_dw16"), volumeTolerance: 1e-6, boundsTolerance: 0.001)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `lipless 2x1x3 shell matches OpenSCAD`() async throws {
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16, lipStyle: .removed)
        try await expectMatchesReference("init_2x1x3_lipless", bin.shell(cornerSegments: 16), references: refs, volumeTolerance: 1e-4)
    }

    @Test func `public shell stays within 1 percent of OpenSCAD`() async throws {
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16)
        let problems = compare(try await measure(bin.shell()), try ReferenceSet.containing().metrics("init_2x1x3"), volumeTolerance: 0.01, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `cut_move places geometry at the compartment center`() async throws {
        let bin = BinGeometry(gridX: 3, gridY: 2, height: 16)
        let marker = Box([1, 1, 1]).aligned(at: .centerXY)
        let actual = try await measure(bin.placed(x: 1, y: 0, w: 1, h: 1, marker))
        let problems = compare(actual, try ReferenceSet.containing().metrics("cut_move_marker"), volumeTolerance: 1e-6, boundsTolerance: 0.001)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `cut_move uses the internal height when set`() async throws {
        let bin = BinGeometry(gridX: 3, gridY: 2, height: 16, internalHeight: 20)
        let marker = Box([1, 1, 1]).aligned(at: .centerXY)
        let actual = try await measure(bin.placed(x: 1, y: 0, w: 1, h: 1, marker))
        let problems = compare(actual, try ReferenceSet.containing().metrics("cut_move_marker_dh0"), volumeTolerance: 1e-6, boundsTolerance: 0.001)
        #expect(problems.isEmpty, "\(problems)")
    }
}
