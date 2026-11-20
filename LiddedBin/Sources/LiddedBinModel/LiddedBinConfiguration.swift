import GridfinityRebuilt

/// Interior_Style
public enum InteriorStyle: String, Sendable, CaseIterable {
    case minimal
    case partialRaised = "partial_raised"
}

/// Lip_Grips
public enum LipGrips: String, Sendable, CaseIterable {
    case none, x, y, xy
}

/// Lid_Orientation
public enum LidOrientation: String, Sendable, CaseIterable {
    case up, down, left, right
}

/// div_pattern (the `custom` pattern is not ported)
public enum CompartmentPattern: String, Sendable, CaseIterable {
    case grid
    case multiSize = "multisize"
}

/// The detent that holds the lid closed.
public enum DetentStyle: String, Sendable, CaseIterable {
    /// lid-bin.scad's detent: a round bump 0.6 mm deep and a notch 0.45 mm deeper than the bump,
    /// so a closed lid sits clear of the bump.
    case original
    /// A seated catch: an asymmetric bump (a gentle ramp toward the open end, a steep face toward
    /// the closed end) that overlaps the plate edge by the detent interference, and a notch that
    /// is the bump grown by a 0.05 mm seat clearance, so the bump nests in the notch of a closed lid.
    case seated
}

/// Part
public enum LiddedBinPart: String, Sendable, CaseIterable {
    case bin
    case lid
    case bothClosed = "both_closed"
    case bothOpen = "both_open"
    case lidOnPlate = "lid_on_plate"
    case bothSeparated = "both_separated"
    case binSlice = "bin_slice"
}

/// The user-facing settings of lid-bin.scad.
public struct LiddedBinConfiguration: Sendable {
    /// gridx
    public var gridX = 2
    /// gridy
    public var gridY = 2
    /// gridz
    public var gridZ = 3.0
    /// gridz_define
    public var heightMode: HeightMode = .units
    /// enable_zsnap
    public var snapHeight = false
    /// height_internal
    public var internalHeightOverride = 0.0
    /// Interior_Style
    public var interiorStyle: InteriorStyle = .minimal
    /// Lip_Grips
    public var lipGrips: LipGrips = .xy
    /// Lid_Orientation
    public var lidOrientation: LidOrientation = .left
    /// div_pattern
    public var compartmentPattern: CompartmentPattern = .grid
    /// divx: the number of compartments along X. 1 is a single compartment with no dividers, N gives
    /// N - 1 dividers, and 0 also gives one open space.
    public var divX = 6
    /// divy: the number of compartments along Y, counted as `divX` is.
    public var divY = 6
    /// div_multiple
    public var divMultiple = 2.0
    /// Overrides the corner segment count so output matches an OpenSCAD reference built with a
    /// fixed `$fn`. Nil in production. This is a tessellation parity setting used by the tests
    /// to match OpenSCAD, not a design parameter, and must not be exposed in the customizer.
    public var cornerSegments: Int? = nil

    // Lid fit. These are not settings of lid-bin.scad: they tune how the lid sits in the bin.
    // `openSCADOriginal` sets each of them to the value that reproduces lid-bin.scad.

    /// The gap in mm between the lid and the slot on each side. Smaller is a tighter fit; the
    /// original model used 0.45.
    public var lidClearance = 0.20

    /// The rise in mm of the bin's slot roof, the slope that holds the lid down. The matching
    /// chamfer on the lid's edge follows the same slope and comes out about 0.6 times as tall.
    /// The run is fixed by the wall (0.7 mm), so a larger rise makes the roof steeper. The
    /// original model's equivalent is 0.8 (a 45 degree roof).
    public var lidChamfer = 1.4

    /// How far in mm the bump on the bin overlaps the lid's edge as the lid slides past it. More
    /// is a firmer click and a stiffer lid. The bump protrudes the lid clearance plus this from
    /// the slot face, so the overlap does not change with the clearance. The original model used 0.15.
    public var detentInterference = 0.25

    /// The detent shape. `.seated` is the catch the lid snaps into; `.original` is lid-bin.scad's
    /// detent, which `detentInterference` does not affect.
    public var detentStyle: DetentStyle = .seated

    public init() {}

    /// The configuration with every lid fit field set to the value that reproduces lid-bin.scad
    /// (`lidClearance = 0.45`, `lidChamfer = 0.8`, the original detent with its 0.15 interference).
    /// The OpenSCAD reference tests start from this.
    public static var openSCADOriginal: LiddedBinConfiguration {
        var c = LiddedBinConfiguration()
        c.lidClearance = 0.45
        c.lidChamfer = 0.8
        c.detentInterference = 0.15
        c.detentStyle = .original
        return c
    }
}
