import Cadova
import GridfinityRebuilt

/// The ranges the baseplate model accepts. The customizer offers the same ranges, so a visitor
/// cannot leave them. The maxima come from the build-time benchmark in
/// docs/superpowers/notes/2026-11-baseplate-build-times.md.
public struct BaseplateLimits: Sendable {
    /// Cells per axis in grid-cells mode. 14 x 14 is the largest square that builds natively in
    /// under 5 seconds in the slowest style (4.6 s for screw together with 3 screws per cell; 15 x 15
    /// takes 5.4 s). The build time follows the cell count, so no product cap is needed.
    public static let gridSize = 1...10
    /// The drawer length per axis in drawer mode, in mm. 42 mm is one cell (`l_grid`), so a
    /// drawer always holds at least one cell. 420 mm is 10 cells, the same maximum as `gridSize`.
    public static let drawerSize = 42.0...420.0
    public static let screwsPerCell = 1...3
    /// The range of the fit values (`fitx`, `fity`).
    public static let fit = -1.0...1.0
    // The original has no ranges for the three screw values. These keep the geometry valid:
    // a channel needs a positive diameter that fits the 42 mm cell, a head must be wider than
    // the thread, and the gap between heads of one cell cannot push the channels off the cell.
    public static let screwDiameter = 1.5...6.0
    public static let screwHeadDiameter = 3.0...12.0
    public static let screwSpacing = 0.0...3.0
}

private func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
}

public extension BaseplateConfiguration {
    /// A copy with every value clamped to what the model supports. In-range input is returned
    /// unchanged.
    ///
    /// A `gridX` or `gridY` of 0 means "fill the drawer" and is kept only when the matching
    /// drawer length holds at least one cell: a shorter drawer is raised to one cell (42 mm), so
    /// the plate never has zero cells. A drawer length of 0 with a positive grid size means "no
    /// minimum" and is kept.
    func validated() -> BaseplateConfiguration {
        var c = self
        c.gridX = clamp(c.gridX, 0...BaseplateLimits.gridSize.upperBound)
        c.gridY = clamp(c.gridY, 0...BaseplateLimits.gridSize.upperBound)
        c.drawerX = Self.validatedDrawer(c.drawerX, fillsDrawer: c.gridX == 0)
        c.drawerY = Self.validatedDrawer(c.drawerY, fillsDrawer: c.gridY == 0)
        c.screwsPerCell = clamp(c.screwsPerCell, BaseplateLimits.screwsPerCell)
        c.fitX = clamp(c.fitX, BaseplateLimits.fit)
        c.fitY = clamp(c.fitY, BaseplateLimits.fit)
        c.screwDiameter = clamp(c.screwDiameter, BaseplateLimits.screwDiameter)
        c.screwHeadDiameter = clamp(c.screwHeadDiameter, BaseplateLimits.screwHeadDiameter)
        c.screwSpacing = clamp(c.screwSpacing, BaseplateLimits.screwSpacing)
        return c
    }

    private static func validatedDrawer(_ length: Double, fillsDrawer: Bool) -> Double {
        if length <= 0 && !fillsDrawer { return 0 }
        return clamp(length, BaseplateLimits.drawerSize)
    }
}

/// The plain values the customizer collects, with the defaults of gridfinity-rebuilt-baseplate.scad.
public struct BaseplateInput: Sendable, Equatable {
    /// The single source of the customizer's default values.
    public static let defaults = BaseplateInput()

    public var sizing: PlateSizing = .gridCells
    public var gridX = 5
    public var gridY = 5
    public var drawerX = 210.0
    public var drawerY = 210.0
    public var fitX = 0.0
    public var fitY = 0.0
    public var plateStyle: PlateStyle = .thin
    public var magnetHoles = true
    public var screwHoles: ScrewHoleStyle = .counterbore
    public var screwDiameter = 3.35
    public var screwHeadDiameter = 5.0
    public var screwSpacing = 0.5
    public var screwsPerCell = 1

    public init() {}

    /// The validated configuration. Grid-cells mode uses the cell counts and no drawer; drawer
    /// mode lets the drawer decide the cell counts (`gridX = gridY = 0`).
    public var configuration: BaseplateConfiguration {
        var c = BaseplateConfiguration()
        switch sizing {
        case .gridCells:
            c.gridX = gridX; c.gridY = gridY
            c.drawerX = 0; c.drawerY = 0
        case .drawer:
            c.gridX = 0; c.gridY = 0
            c.drawerX = drawerX; c.drawerY = drawerY
        }
        c.fitX = fitX; c.fitY = fitY
        c.plateStyle = plateStyle
        c.magnetHoles = magnetHoles
        c.screwHoles = screwHoles
        c.screwDiameter = screwDiameter
        c.screwHeadDiameter = screwHeadDiameter
        c.screwSpacing = screwSpacing
        c.screwsPerCell = screwsPerCell
        return c.validated()
    }
}

extension PlateStyle: ParameterChoice {
    public var displayName: String {
        switch self {
        case .thin: "Thin"
        case .weighted: "Weighted"
        case .skeletonized: "Skeletonized"
        case .screwTogether: "Screw together"
        case .screwTogetherMinimal: "Screw together minimal"
        }
    }
}

extension ScrewHoleStyle: ParameterChoice {
    public var displayName: String {
        switch self {
        case .none: "None"
        case .countersink: "Countersink"
        case .counterbore: "Counterbore"
        }
    }
}

extension PlateSizing: ParameterChoice {
    public var displayName: String {
        switch self {
        case .gridCells: "Grid cells"
        case .drawer: "Drawer size"
        }
    }
}
