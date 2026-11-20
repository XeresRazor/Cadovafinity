import Testing
import Cadova
import GridfinityTestSupport
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
        #expect(v.divX == 1)
        #expect(LiddedBinLimits.compartments == 1...12)
        #expect(v.divX == LiddedBinLimits.compartments.lowerBound)
        #expect(v.divY == LiddedBinLimits.compartments.upperBound)
        #expect(v.divMultiple == LiddedBinLimits.divMultiple.lowerBound)
        c.divMultiple = 99
        #expect(c.validated().divMultiple == LiddedBinLimits.divMultiple.upperBound)
    }

    @Test func `a compartment count of 0 becomes 1 and in-range counts are unchanged`() {
        var c = LiddedBinConfiguration()
        c.divX = 0; c.divY = 0
        #expect(c.validated().divX == 1 && c.validated().divY == 1)
        for n in 1...12 {
            c.divX = n; c.divY = n
            #expect(c.validated().divX == n && c.validated().divY == n)
        }
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
        #expect(LiddedBinLimits.lidChamfer == 0.8...1.8)
    }

    @Test func `detent interference is clamped`() {
        var c = LiddedBinConfiguration()
        c.detentInterference = 0
        #expect(c.validated().detentInterference == LiddedBinLimits.detentInterference.lowerBound)
        c.detentInterference = 2
        #expect(c.validated().detentInterference == LiddedBinLimits.detentInterference.upperBound)
        c.detentInterference = 0.35
        #expect(c.validated().detentInterference == 0.35)
        #expect(LiddedBinConfiguration().validated().detentInterference == 0.25)
        #expect(LiddedBinConfiguration.openSCADOriginal.validated().detentInterference == 0.15)
        #expect(LiddedBinConfiguration.openSCADOriginal.validated().detentStyle == .original)
        #expect(LiddedBinLimits.detentInterference == 0.10...0.40)
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

    @Test func `the height ranges allow the same shortest and tallest bin`() {
        #expect(LiddedBinLimits.unitsHeight == 2...12)
        #expect(abs(LiddedBinLimits.internalHeight.lowerBound - 6.8) < 1e-9)
        #expect(abs(LiddedBinLimits.internalHeight.upperBound - 76.8) < 1e-9)
        #expect(LiddedBinLimits.externalHeight == 14...84)
    }

    @Test func `heights below the shortest bin are clamped and in-range heights are unchanged`() {
        var c = LiddedBinConfiguration()
        c.heightMode = .units
        c.gridZ = 1
        #expect(c.validated().gridZ == 2)
        c.gridZ = 2; #expect(c.validated().gridZ == 2)
        c.gridZ = 2.5; #expect(c.validated().gridZ == 2.5)
        c.heightMode = .internalMillimeters
        c.gridZ = 5
        #expect(abs(c.validated().gridZ - 6.8) < 1e-9)
        c.gridZ = 6.5
        #expect(abs(c.validated().gridZ - 6.8) < 1e-9)
        c.gridZ = 20; #expect(c.validated().gridZ == 20)
        c.heightMode = .externalMillimeters
        c.gridZ = 13.9
        #expect(c.validated().gridZ == 14)
        c.gridZ = 14; #expect(c.validated().gridZ == 14)
        c.gridZ = 30; #expect(c.validated().gridZ == 30)
    }

    /// The customizer's shortest bin in each height style (2 units, internal 6.8 mm, overall 14 mm)
    /// is the same 9 mm storage height, and its compartments are not sealed under the lid: the closed
    /// lid and bin overlap by about 1.4 mm^3 (the 1 unit bin gave 5728 mm^3).
    @Test(arguments: [InteriorStyle.minimal, .partialRaised, .flushRaised])
    func `the shortest bin of every height style builds the same storage height with a small overlap`(
        _ style: InteriorStyle
    ) async throws {
        for heightStyle in [HeightStyle.sevenMillimeterUnits, .internalHeight, .externalHeight] {
            var i = LiddedBinInput()
            i.heightStyle = heightStyle
            i.unitsHeight = -10; i.internalHeight = -10; i.externalHeight = -10
            i.interiorStyle = style
            i.divX = 2; i.divY = 2
            var c = i.configuration
            c.cornerSegments = 16
            #expect(c.gridZ == LiddedBinLimits.heightRange(for: c.heightMode).lowerBound)
            let d = LiddedBinDesign(c)
            #expect(abs(d.storageHeight - 9) < 1e-9, "\(heightStyle) \(style)")
            let overlap = try await measure(d.binSolid(pockets: d.pockets()).intersecting { d.lidBody() })
            #expect(overlap.volume < 8, "\(heightStyle) \(style): \(overlap.volume)")
        }
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
