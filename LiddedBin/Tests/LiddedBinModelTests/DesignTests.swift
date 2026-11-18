import Testing
import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

struct DesignTests {
    @Test func `derived heights for the default configuration`() {
        let design = LiddedBinDesign(LiddedBinConfiguration())
        #expect(abs(design.storageHeight - 16) < 1e-9)
        #expect(abs(design.innerHeight - 19.4) < 1e-9)
    }

    @Test func `wall thickness is 1_6`() {
        let design = LiddedBinDesign(LiddedBinConfiguration())
        #expect(design.d.dWall == 1.6)
        #expect(abs(design.d.dMagic - -2.5) < 1e-12)
    }

    @Test func `lid position follows orientation`() {
        var c = LiddedBinConfiguration()
        c.lidOrientation = .left
        #expect(LiddedBinDesign(c).lidPosition() == Vector2D(-84, 0))
        c.lidOrientation = .up
        #expect(LiddedBinDesign(c).lidPosition() == Vector2D(0, 84))
        c.lidOrientation = .right
        #expect(LiddedBinDesign(c).lidPosition(adjust: 10) == Vector2D(94, 0))
        c.lidOrientation = .down
        #expect(LiddedBinDesign(c).lidPosition(adjust: -7.096) == Vector2D(0, -(84 - 7.096)))
    }

    @Test func `pocket size`() {
        let size = LiddedBinDesign(LiddedBinConfiguration()).pocketSize(xUnits: 1.0 / 3, yUnits: 1.0 / 3)
        #expect(abs(size.x - 12.383333333) < 1e-6)
        #expect(abs(size.y - 12.383333333) < 1e-6)
    }

    @Test func `height modes map to the library`() {
        var c = LiddedBinConfiguration()
        c.heightMode = .internalMillimeters
        c.gridZ = 20
        c.snapHeight = true
        #expect(abs(LiddedBinDesign(c).storageHeight - 23) < 1e-9)   // same as height(20,1,0,true) in standard.scad
    }
}
