/// The baseplate constants from gridfinity-rebuilt-openscad's `standard.scad`.
public struct BaseplateDimensions: Sendable {
    /// Baseplate bottom part height (`bp_h_bot`).
    public var bpHBot = 6.4
    /// Baseplate bottom cutout rectangle size (`bp_cut_size`).
    public var bpCutSize = 21.4
    /// Baseplate bottom cutout rectangle depth (`bp_cut_depth`).
    public var bpCutDepth = 4.0
    /// Baseplate bottom cutout rounded part width (`bp_rcut_width`).
    public var bpRcutWidth = 8.5
    /// Baseplate bottom cutout rounded part length (`bp_rcut_length`).
    public var bpRcutLength = 4.25
    /// Baseplate bottom cutout rounded part depth (`bp_rcut_depth`).
    public var bpRcutDepth = 2.0
    /// Baseplate clearance offset (`bp_xy_clearance`).
    public var bpXYClearance = 0.5
    /// Countersink diameter for baseplate (`d_cs`).
    public var dCs = 2.5
    /// Radius of cutout for skeletonized baseplate (`r_skel`).
    public var rSkel = 2.0
    /// Baseplate counterbore radius (`r_cb`).
    public var rCb = 2.75
    /// Baseplate counterbore depth (`h_cb`).
    public var hCb = 3.0
    /// Minimum baseplate thickness when skeletonized (`h_skel`).
    public var hSkel = 1.0

    public init() {}

    public static let standard = BaseplateDimensions()
}
