import Testing
import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

struct CustomizerInputTests {
    @Test func `default input equals the default configuration`() {
        let c = LiddedBinInput().configuration
        let d = LiddedBinConfiguration()
        #expect(c.gridX == d.gridX && c.gridY == d.gridY && c.gridZ == d.gridZ)
        #expect(c.heightMode == d.heightMode && c.snapHeight == d.snapHeight)
        #expect(c.lipGrips == d.lipGrips && c.lidOrientation == d.lidOrientation)
        #expect(c.interiorStyle == d.interiorStyle && c.compartmentPattern == d.compartmentPattern)
        #expect(c.divX == d.divX && c.divY == d.divY && c.divMultiple == d.divMultiple)
        #expect(c.internalHeightOverride == d.internalHeightOverride)
        #expect(c.cornerSegments == nil)
    }

    @Test func `height style selects the matching field and mode`() {
        var i = LiddedBinInput()
        i.heightStyle = .internalHeight; i.internalHeight = 20; i.unitsHeight = 9
        #expect(i.configuration.heightMode == .internalMillimeters)
        #expect(i.configuration.gridZ == 20)
        i.heightStyle = .externalHeight; i.externalHeight = 30
        #expect(i.configuration.heightMode == .externalMillimeters)
        #expect(i.configuration.gridZ == 30)
        i.heightStyle = .sevenMillimeterUnits
        #expect(i.configuration.heightMode == .units)
        #expect(i.configuration.gridZ == 9)
    }

    @Test func `out-of-range input is clamped`() {
        var i = LiddedBinInput()
        i.gridX = 100; i.divMultiple = 0
        #expect(i.configuration.gridX == LiddedBinLimits.gridSize.upperBound)
        #expect(i.configuration.divMultiple == LiddedBinLimits.divMultiple.lowerBound)
    }

    @Test func `units mode ignores the snap flag`() {
        var i = LiddedBinInput()
        i.heightStyle = .sevenMillimeterUnits; i.unitsHeight = 5
        i.snapHeight = false
        let off = LiddedBinDesign(i.configuration).storageHeight
        i.snapHeight = true
        let on = LiddedBinDesign(i.configuration).storageHeight
        #expect(on == off)
    }

    @Test func `other fields are passed through`() {
        var i = LiddedBinInput()
        i.snapHeight = true; i.internalBlockHeight = 4
        i.lipGrips = .none; i.lidOrientation = .up
        i.interiorStyle = .partialRaised; i.compartmentPattern = .multiSize
        i.divX = 3; i.divY = 4; i.divMultiple = 3
        let c = i.configuration
        #expect(c.snapHeight && c.internalHeightOverride == 4)
        #expect(c.lipGrips == .none && c.lidOrientation == .up)
        #expect(c.interiorStyle == .partialRaised && c.compartmentPattern == .multiSize)
        #expect(c.divX == 3 && c.divY == 4 && c.divMultiple == 3)
    }

    @Test func `choices have unique string raw values and display names`() {
        func check<T: ParameterChoice>(_: T.Type) {
            let raws = T.allCases.map { String($0.rawValue) }
            #expect(Set(raws).count == raws.count)
            #expect(T.allCases.allSatisfy { !$0.displayName.isEmpty })
        }
        check(InteriorStyle.self); check(LipGrips.self); check(LidOrientation.self)
        check(CompartmentPattern.self); check(HeightStyle.self)
    }

    @Test func `readable display names`() {
        #expect(LipGrips.xy.displayName == "Along X and Y")
        #expect(HeightStyle.externalHeight.displayName == "Overall height")
        #expect(HeightStyle.sevenMillimeterUnits.displayName == "7 mm units")
        #expect(InteriorStyle.partialRaised.displayName == "Partially raised")
        #expect(CompartmentPattern.multiSize.displayName == "Two sizes")
        #expect(LidOrientation.left.displayName == "Left")
    }

    @Test func `choices round trip through parameter strings`() {
        for s in LipGrips.allCases { #expect(LipGrips(parameterString: s.parameterString) == s) }
        for s in HeightStyle.allCases { #expect(HeightStyle(parameterString: s.parameterString) == s) }
        for s in InteriorStyle.allCases { #expect(InteriorStyle(parameterString: s.parameterString) == s) }
        for s in CompartmentPattern.allCases { #expect(CompartmentPattern(parameterString: s.parameterString) == s) }
    }
}
