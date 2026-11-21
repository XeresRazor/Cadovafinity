import Foundation

/// The dimensions from gridfinity-rebuilt-openscad's `standard.scad`.
///
/// Names follow the OpenSCAD variables in camelCase (`r_base` is `rBase`).
/// Wall thickness is a variable because designs such as the lidded bin override it.
public struct Dimensions: Sendable {
    /// Height of the base.
    public var hBase = 5.0
    /// Outside rounded radius of bin.
    public var rBase = 4.0
    /// Lower base chamfer "radius".
    public var rC1 = 0.8
    /// Upper base chamfer "radius".
    public var rC2 = 2.4
    /// Bottom thickness of bin.
    public var hBot = 2.2
    /// Outside radii 1, 2 and 3.
    public var rFo1 = 8.5
    public var rFo2 = 3.2
    public var rFo3 = 1.6
    /// Length of a grid unit.
    public var lGrid = 42.0
    /// Width of divider between compartments.
    public var dDiv = 1.2
    /// Minimum wall thickness.
    public var dWall = 0.95
    /// Tolerance fit factor.
    public var dClear = 0.25
    /// Lip height.
    public var hLip = 3.548
    /// Top edge fillet radius.
    public var rF1 = 0.6
    /// Internal fillet radius.
    public var rF2 = 2.8
    /// Screw hole radius (`r_hole1`).
    public var rHole1 = 1.5
    /// Magnet hole radius (`r_hole2`).
    public var rHole2 = 3.25
    /// Center-to-center distance between holes (`d_hole`).
    public var dHole = 26.0
    /// Distance of a hole from the side of the bin (`d_hole_from_side`).
    public var dHoleFromSide = 8.0
    /// Magnet hole depth (`h_hole`).
    public var hHole = 2.4
    /// Slit depth, the printer layer height (`h_slit`).
    public var hSlit = 0.2

    public init() {}

    public static let standard = Dimensions()

    /// `d_wall2` in standard.scad.
    public var dWall2: Double { rBase - rC1 - dClear * 2.0.squareRoot() }
    /// `d_magic` in standard.scad.
    public var dMagic: Double { -2 * dClear - 2 * dWall + dDiv }
}
