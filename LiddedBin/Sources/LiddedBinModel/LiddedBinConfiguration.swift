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

/// Part
public enum LiddedBinPart: String, Sendable, CaseIterable {
    case bin
    case lid
    case bothClosed = "both_closed"
    case bothOpen = "both_open"
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
    /// divx
    public var divX = 6
    /// divy
    public var divY = 6
    /// div_multiple
    public var divMultiple = 2.0
    /// Overrides the corner segment count so output matches an OpenSCAD reference built with a
    /// fixed `$fn`. Nil in production. This is a tessellation parity setting used by the tests
    /// to match OpenSCAD, not a design parameter, and must not be exposed in the customizer.
    public var cornerSegments: Int? = nil

    public init() {}
}
