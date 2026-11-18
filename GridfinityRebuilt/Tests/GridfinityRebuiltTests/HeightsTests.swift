import Testing
@testable import GridfinityRebuilt

struct HeightsTests {
    let d = Dimensions.standard

    @Test func `height modes match OpenSCAD`() {
        #expect(abs(d.binHeight(3) - 16) < 1e-9)                                   // height(3)
        #expect(abs(d.binHeight(3, snap: false) - 16) < 1e-9)                      // height(3,0,0,false)
        #expect(abs(d.binHeight(20, mode: .internalMillimeters) - 23) < 1e-9)      // height(20,1,0,true)
        #expect(abs(d.binHeight(20, mode: .internalMillimeters, snap: false) - 22.2) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters) - 30) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters, lip: .removed, snap: false) - 21.452) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters, lip: .removedKeepHeight, snap: false) - 28.548) < 1e-9)
    }
}
