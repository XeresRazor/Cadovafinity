/// The lid fit constants from lid-bin.scad.
struct LidFit: Sendable {
    var wallThickness = 1.2          // lid_wall_thickness
    var thickness = 0.9              // lid_thickness
    var hFitTolerance = 1.1          // lid_hfit_tolerance
    var vFitTolerance = 0.1          // lid_vfit_tolerance
    var vPosTolerance = 0.2          // lid_vpos_tolerance
    var lipFitTolerance: Double { min(0.1, vFitTolerance) }   // lid_lip_fit_tolerance
    var separatorWallThickness = 1.2 // bin_separator_wall_thickness
    var interiorBaseWallAdjust = 0.4 // interior_base_wall_adjust
}
