import Testing
import Cadova
@testable import GridfinityModels

struct BaseplateInputTests {
    @Test func `defaults equal the OpenSCAD defaults`() {
        let d = BaseplateInput.defaults
        #expect(d.gridX == 5 && d.gridY == 5)
        #expect(d.plateStyle == .thin && d.magnetHoles && d.screwHoles == .counterbore)
        #expect(d.screwDiameter == 3.35 && d.screwHeadDiameter == 5 && d.screwSpacing == 0.5)
        #expect(d.screwsPerCell == 1 && d.fitX == 0 && d.fitY == 0)
        #expect(d.sizing == .gridCells)
        #expect(d.drawerX == 210 && d.drawerY == 210)
        // And the configuration of the defaults is the plain configuration of the original.
        let c = d.configuration, o = BaseplateConfiguration()
        #expect(c.gridX == o.gridX && c.gridY == o.gridY && c.plateStyle == o.plateStyle)
        #expect(c.magnetHoles == o.magnetHoles && c.screwHoles == o.screwHoles)
        #expect(c.screwDiameter == o.screwDiameter && c.screwHeadDiameter == o.screwHeadDiameter)
        #expect(c.screwSpacing == o.screwSpacing && c.screwsPerCell == o.screwsPerCell)
        #expect(c.drawerX == 0 && c.drawerY == 0 && c.fitX == 0 && c.fitY == 0)
    }

    @Test func `grid cells mode uses the cell counts and ignores the drawer`() {
        var i = BaseplateInput()
        i.sizing = .gridCells; i.gridX = 3; i.gridY = 4; i.drawerX = 300; i.drawerY = 200
        let c = i.configuration
        #expect(c.gridX == 3 && c.gridY == 4)
        #expect(c.drawerX == 0 && c.drawerY == 0)
    }

    @Test func `drawer mode uses the drawer and zero cell counts`() {
        var i = BaseplateInput()
        i.sizing = .drawer; i.gridX = 3; i.gridY = 4; i.drawerX = 300; i.drawerY = 200
        i.fitX = 0.5; i.fitY = -0.5
        let c = i.configuration
        #expect(c.gridX == 0 && c.gridY == 0)
        #expect(c.drawerX == 300 && c.drawerY == 200)
        #expect(c.fitX == 0.5 && c.fitY == -0.5)
        #expect(BaseplateDesign(c).cellsX == 7 && BaseplateDesign(c).cellsY == 4)
    }

    @Test func `a tiny drawer still gives one cell`() {
        var i = BaseplateInput()
        i.sizing = .drawer; i.drawerX = 5; i.drawerY = 5
        let d = BaseplateDesign(i.configuration)
        #expect(d.cellsX == 1 && d.cellsY == 1)
    }

    @Test func `out-of-range input is clamped`() {
        var i = BaseplateInput()
        i.gridX = 100; i.screwsPerCell = 10
        #expect(i.configuration.gridX == BaseplateLimits.gridSize.upperBound)
        #expect(i.configuration.screwsPerCell == 3)
    }

    @Test func `choices have unique raw values and display names`() {
        func check<T: ParameterChoice & Equatable>(_ type: T.Type, _ names: [String]) {
            #expect(T.allCases.map { $0.parameterString }.count == Set(T.allCases.map { $0.parameterString }).count)
            #expect(T.allCases.map(\.displayName) == names)
            for c in T.allCases { #expect(T(parameterString: c.parameterString) == c) }
        }
        check(PlateStyle.self, ["Thin", "Weighted", "Skeletonized", "Screw together", "Screw together minimal"])
        check(ScrewHoleStyle.self, ["None", "Countersink", "Counterbore"])
        check(PlateSizing.self, ["Grid cells", "Drawer size"])
    }
}
