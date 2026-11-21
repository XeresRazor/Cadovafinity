/// style_plate
public enum PlateStyle: Int, Sendable, CaseIterable {
    /// A plate without a floor: the sockets go straight through.
    case thin = 0
    /// A 6.4 mm floor with weight pockets under each cell.
    case weighted
    /// A floor cut away to a skeleton outline, keeping bosses around the holes.
    case skeletonized
    /// A 6.75 mm floor, skeletonized, with screw channels across the plate edges.
    case screwTogether
    /// A 6.75 mm floor reduced to a square opening per cell, with screw channels.
    case screwTogetherMinimal
}

/// style_hole of the baseplate: the screw hole cut through the floor at each hole position.
public enum ScrewHoleStyle: Int, Sendable, CaseIterable {
    case none = 0
    case countersink
    case counterbore
}

/// How the customizer page sizes the plate: by a cell count, or by filling a drawer.
public enum PlateSizing: String, Sendable, CaseIterable {
    case gridCells = "grid_cells"
    case drawer
}

/// The settings of gridfinity-rebuilt-baseplate.scad, with its defaults.
public struct BaseplateConfiguration: Sendable {
    /// gridx: cells along X. 0 fills `drawerX` with as many whole cells as fit.
    public var gridX = 5
    /// gridy: cells along Y. 0 fills `drawerY` with as many whole cells as fit.
    public var gridY = 5
    /// style_plate
    public var plateStyle: PlateStyle = .thin
    /// enable_magnet
    public var magnetHoles = true
    /// style_hole
    public var screwHoles: ScrewHoleStyle = .counterbore
    /// d_screw: the screw-together channel diameter, in mm.
    public var screwDiameter = 3.35
    /// d_screw_head: in mm. The plate uses it only to space the screws of one cell.
    public var screwHeadDiameter = 5.0
    /// screw_spacing: the gap in mm between the screw heads of one cell.
    public var screwSpacing = 0.5
    /// n_screws: screw channels per cell edge.
    public var screwsPerCell = 1
    /// distancex: the minimum plate length along X in mm (0 ignores it).
    public var drawerX = 0.0
    /// distancey: the minimum plate length along Y in mm (0 ignores it).
    public var drawerY = 0.0
    /// fitx: where the extra length along X goes, from -1 to 1.
    public var fitX = 0.0
    /// fity: where the extra length along Y goes, from -1 to 1.
    public var fitY = 0.0

    public init() {}
}
