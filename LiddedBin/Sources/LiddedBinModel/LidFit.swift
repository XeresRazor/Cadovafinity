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
    /// The rise in mm of the slot roof slope over its run, which the lid tongue's chamfer
    /// follows. `originalChamfer` (0.8) gives the original 45 degree roof.
    var chamfer = LidFit.originalChamfer

    /// The shape of the detent: the bump on the bin's slot face and the notch in the lid's plate
    /// edge. `.original` is lid-bin.scad's (a round bump 0.6 deep, a notch 0.45 deeper than it).
    var detentStyle: DetentStyle = .original
    /// How far in mm the seated bump overlaps the lid's plate edge while the lid slides past it.
    /// The bump protrudes `sideClearance + detentInterference` from the slot face. Only used by
    /// `.seated`; the original bump's 0.6 protrusion gives 0.15 at the original 0.45 side gap.
    var detentInterference = LidFit.originalDetentInterference

    /// The roof rise that reproduces the original 45 degree slot roof of lid-bin.scad.
    static let originalChamfer = 0.8
    /// The overlap of lid-bin.scad's bump with the plate edge (0.6 protrusion less the 0.45 gap).
    static let originalDetentInterference = 0.15
    /// The gap in mm all round between the seated bump and the lid's notch when the lid is closed.
    static let detentSeatClearance = 0.05
    /// The angle in degrees between the slide direction and the bump face the lid meets first
    /// when closing (the face toward the open end). Gentle, so the lid rides onto the bump.
    static let detentRampAngle = 30.0
    /// The angle in degrees between the slide direction and the bump face toward the closed end.
    /// Steep, so the notch holds the lid closed until it is pushed.
    static let detentStopAngle = 65.0
    /// The length in mm of the bump's flat top along the slide direction.
    static let detentFlatLength = 0.8

    /// How far the seated bump protrudes from the slot face.
    var detentProtrusion: Double { sideClearance + detentInterference }

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
