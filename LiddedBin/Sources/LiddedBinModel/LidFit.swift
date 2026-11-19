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
    /// The offset that tightens the gap around the lid tongue (`offset(delta = 0.30)` in
    /// `gf_bin_lid`). 0.30 reproduces the original model.
    var lipClearance = 0.30
    /// The gap in mm between the lid's plate edge and the slot face, on each side. Nil means
    /// the value that reproduces the original model for the current `hFitTolerance` and
    /// `wallThickness` (the original `sz = 0.5 + 3 * lid_hfit_tolerance` inset).
    var sideClearanceOverride: Double?

    init(sideClearance: Double? = nil) {
        sideClearanceOverride = sideClearance
    }

    var sideClearance: Double {
        get { sideClearanceOverride ?? (3 * hFitTolerance - 2 * wallThickness) / 2 }
        set { sideClearanceOverride = newValue }
    }

    /// How far the lid's plate and tongue are inset from the block outline (`sz` in `gf_bin_lid`).
    var plateInset: Double { 0.5 + 2 * wallThickness + 2 * sideClearance }
}
