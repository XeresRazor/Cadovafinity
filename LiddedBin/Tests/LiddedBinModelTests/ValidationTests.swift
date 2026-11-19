import Testing
@testable import LiddedBinModel
import GridfinityRebuilt

struct ValidationTests {
    @Test func `in-range configuration is unchanged`() {
        var c = LiddedBinConfiguration()
        c.gridX = 3; c.gridY = 2; c.gridZ = 4; c.divX = 4; c.divY = 2; c.divMultiple = 3
        c.internalHeightOverride = 5
        let v = c.validated()
        #expect(v.gridX == 3 && v.gridY == 2)
        #expect(v.gridZ == 4)
        #expect(v.divX == 4 && v.divY == 2)
        #expect(v.divMultiple == 3)
        #expect(v.internalHeightOverride == 5)
        #expect(v.heightMode == c.heightMode)
    }

    @Test func `grid sizes are clamped to the supported range`() {
        var c = LiddedBinConfiguration()
        c.gridX = 0; c.gridY = 99
        let v = c.validated()
        #expect(v.gridX == LiddedBinLimits.gridSize.lowerBound)
        #expect(v.gridY == LiddedBinLimits.gridSize.upperBound)
    }

    @Test func `dividers and multiple are clamped`() {
        var c = LiddedBinConfiguration()
        c.divX = -4; c.divY = 500; c.divMultiple = 0
        let v = c.validated()
        #expect(v.divX == LiddedBinLimits.dividers.lowerBound)
        #expect(v.divY == LiddedBinLimits.dividers.upperBound)
        #expect(v.divMultiple == LiddedBinLimits.divMultiple.lowerBound)
        c.divMultiple = 99
        #expect(c.validated().divMultiple == LiddedBinLimits.divMultiple.upperBound)
    }

    @Test func `lid clearance is clamped`() {
        var c = LiddedBinConfiguration()
        c.lidClearance = 0
        #expect(c.validated().lidClearance == LiddedBinLimits.lidClearance.lowerBound)
        c.lidClearance = 3
        #expect(c.validated().lidClearance == LiddedBinLimits.lidClearance.upperBound)
        c.lidClearance = 0.3
        #expect(c.validated().lidClearance == 0.3)
        #expect(LiddedBinConfiguration.openSCADOriginal.validated().lidClearance == 0.45)
    }

    @Test func `lid chamfer is clamped`() {
        var c = LiddedBinConfiguration()
        c.lidChamfer = 0.2
        #expect(c.validated().lidChamfer == LiddedBinLimits.lidChamfer.lowerBound)
        c.lidChamfer = 5
        #expect(c.validated().lidChamfer == LiddedBinLimits.lidChamfer.upperBound)
        c.lidChamfer = 1.1
        #expect(c.validated().lidChamfer == 1.1)
        #expect(LiddedBinConfiguration().validated().lidChamfer == 1.4)
        #expect(LiddedBinConfiguration.openSCADOriginal.validated().lidChamfer == 0.8)
        #expect(LiddedBinLimits.lidChamfer == 0.8...2.0)
    }

    @Test func `height is clamped to the range of its mode`() {
        var c = LiddedBinConfiguration()
        c.heightMode = .internalMillimeters
        c.gridZ = 1000
        #expect(c.validated().gridZ == LiddedBinLimits.internalHeight.upperBound)
        c.heightMode = .units
        c.gridZ = -3
        #expect(c.validated().gridZ == LiddedBinLimits.unitsHeight.lowerBound)
        c.heightMode = .externalMillimeters
        c.gridZ = 0
        #expect(c.validated().gridZ == LiddedBinLimits.externalHeight.lowerBound)
    }

    @Test func `internal height override cannot exceed the storage height`() {
        var c = LiddedBinConfiguration()
        c.internalHeightOverride = 10_000
        let v = c.validated()
        let storage = LiddedBinDesign(v).storageHeight
        #expect(v.internalHeightOverride == storage)
        #expect(v.validated().internalHeightOverride == v.internalHeightOverride)
        c.internalHeightOverride = -5
        #expect(c.validated().internalHeightOverride == 0)
    }

    @Test func `validated is idempotent`() {
        var c = LiddedBinConfiguration()
        c.gridX = 0; c.gridY = 50; c.divX = 99; c.divY = -1; c.divMultiple = 9; c.gridZ = 500
        c.internalHeightOverride = 9999
        let once = c.validated()
        let twice = once.validated()
        #expect(twice.gridX == once.gridX && twice.gridY == once.gridY)
        #expect(twice.divX == once.divX && twice.divY == once.divY)
        #expect(twice.divMultiple == once.divMultiple)
        #expect(twice.gridZ == once.gridZ)
        #expect(twice.internalHeightOverride == once.internalHeightOverride)
    }
}
