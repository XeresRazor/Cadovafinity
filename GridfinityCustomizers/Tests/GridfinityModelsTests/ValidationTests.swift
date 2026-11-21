import Testing
import Cadova
@testable import GridfinityModels

struct ValidationTests {
    @Test func `in-range configuration is unchanged`() {
        var c = BaseplateConfiguration()
        c.gridX = 4; c.gridY = 7; c.screwsPerCell = 2; c.fitX = -0.5; c.fitY = 1
        c.screwDiameter = 4; c.screwHeadDiameter = 8; c.screwSpacing = 1
        c.plateStyle = .screwTogether; c.screwHoles = .countersink; c.magnetHoles = false
        let v = c.validated()
        #expect(v.gridX == 4 && v.gridY == 7 && v.screwsPerCell == 2)
        #expect(v.fitX == -0.5 && v.fitY == 1)
        #expect(v.screwDiameter == 4 && v.screwHeadDiameter == 8 && v.screwSpacing == 1)
        #expect(v.plateStyle == .screwTogether && v.screwHoles == .countersink && !v.magnetHoles)
        #expect(v.drawerX == 0 && v.drawerY == 0)
    }

    @Test func `the defaults are in range`() {
        let c = BaseplateConfiguration()
        let v = c.validated()
        #expect(v.gridX == c.gridX && v.screwDiameter == c.screwDiameter)
        #expect(v.screwHeadDiameter == c.screwHeadDiameter && v.screwSpacing == c.screwSpacing)
    }

    @Test func `grid sizes are clamped to the supported range`() {
        var c = BaseplateConfiguration()
        c.gridX = 99; c.gridY = -3
        let v = c.validated()
        #expect(v.gridX == BaseplateLimits.gridSize.upperBound)
        // A negative size becomes 0 (fill the drawer), and the drawer is raised to one cell.
        #expect(v.gridY == 0 && v.drawerY == 42)
    }

    @Test func `a zero grid size with a small drawer raises the drawer to one cell`() {
        var c = BaseplateConfiguration()
        c.gridX = 0; c.gridY = 0; c.drawerX = 10; c.drawerY = 41.9
        let v = c.validated()
        #expect(v.drawerX == 42 && v.drawerY == 42)
        #expect(BaseplateDesign(v).cellsX == 1 && BaseplateDesign(v).cellsY == 1)
        c.drawerX = 0
        #expect(c.validated().drawerX == 42)
    }

    @Test func `a zero grid size keeps a drawer that holds a cell`() {
        var c = BaseplateConfiguration()
        c.gridX = 0; c.gridY = 0; c.drawerX = 210; c.drawerY = 300
        let v = c.validated()
        #expect(v.gridX == 0 && v.drawerX == 210 && v.drawerY == 300)
    }

    @Test func `the drawer is clamped to its maximum`() {
        var c = BaseplateConfiguration()
        c.gridX = 0; c.gridY = 0; c.drawerX = 9999; c.drawerY = 9999
        let v = c.validated()
        #expect(v.drawerX == BaseplateLimits.drawerSize.upperBound)
        #expect(v.drawerY == BaseplateLimits.drawerSize.upperBound)
        // A minimum length beside a positive grid size is clamped too; 0 stays "no minimum".
        c.gridX = 3; c.gridY = 3; c.drawerY = 0
        #expect(c.validated().drawerX == BaseplateLimits.drawerSize.upperBound)
        #expect(c.validated().drawerY == 0)
    }

    @Test func `screws per cell and fit are clamped`() {
        var c = BaseplateConfiguration()
        c.screwsPerCell = 0; c.fitX = -5; c.fitY = 5
        var v = c.validated()
        #expect(v.screwsPerCell == BaseplateLimits.screwsPerCell.lowerBound)
        #expect(v.fitX == -1 && v.fitY == 1)
        c.screwsPerCell = 9
        v = c.validated()
        #expect(v.screwsPerCell == 3)
    }

    @Test func `screw sizes are clamped`() {
        var c = BaseplateConfiguration()
        c.screwDiameter = 0; c.screwHeadDiameter = 0; c.screwSpacing = -1
        var v = c.validated()
        #expect(v.screwDiameter == 1.5 && v.screwHeadDiameter == 3 && v.screwSpacing == 0)
        c.screwDiameter = 40; c.screwHeadDiameter = 40; c.screwSpacing = 40
        v = c.validated()
        #expect(v.screwDiameter == 6 && v.screwHeadDiameter == 12 && v.screwSpacing == 3)
    }

    @Test func `validation is idempotent`() {
        var c = BaseplateConfiguration()
        c.gridX = 0; c.gridY = 77; c.drawerX = 3; c.drawerY = 1e6
        c.screwsPerCell = 8; c.fitX = 3; c.fitY = -3
        c.screwDiameter = -1; c.screwHeadDiameter = 99; c.screwSpacing = 9
        let once = c.validated()
        let twice = once.validated()
        #expect(once.gridX == twice.gridX && once.gridY == twice.gridY)
        #expect(once.drawerX == twice.drawerX && once.drawerY == twice.drawerY)
        #expect(once.screwsPerCell == twice.screwsPerCell && once.fitX == twice.fitX && once.fitY == twice.fitY)
        #expect(once.screwDiameter == twice.screwDiameter && once.screwHeadDiameter == twice.screwHeadDiameter)
        #expect(once.screwSpacing == twice.screwSpacing)
    }
}
