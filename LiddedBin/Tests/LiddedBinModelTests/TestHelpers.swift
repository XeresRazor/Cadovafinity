import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

/// A design with `cornerSegments = 16`, as used by every reference test.
func design(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
    var c = LiddedBinConfiguration()
    c.cornerSegments = 16
    edit(&c)
    return LiddedBinDesign(c)
}

/// Part == "lid": translate([0, 0, -$dh - h_base + lid_thickness]) gf_bin_lid()
func lidOnBed(_ design: LiddedBinDesign) -> any Geometry3D {
    design.lidBody().translated(z: -design.storageHeight - design.d.hBase + design.fit.thickness)
}
