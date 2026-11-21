import Cadova
import GridfinityRebuilt

/// A baseplate built from a `BaseplateConfiguration`.
///
/// Port of `gridfinityBaseplate` and `calculate_off` in gridfinity-rebuilt-baseplate.scad
/// (lines 68 to 134). `geometry()` keeps OpenSCAD's placement: the plate top is at
/// `hBase - 0.6` (4.4) and its bottom at `-floorDepth`.
public struct BaseplateDesign: Sendable {
    public let configuration: BaseplateConfiguration
    let d = Dimensions.standard
    let b = BaseplateDimensions.standard

    public init(_ configuration: BaseplateConfiguration) {
        self.configuration = configuration
    }

    var c: BaseplateConfiguration { configuration }
    var cutters: BaseplateCutters { BaseplateCutters(d: d, b: b) }

    /// screw_together
    var screwTogether: Bool { c.plateStyle == .screwTogether || c.plateStyle == .screwTogetherMinimal }

    /// gx: the cell count along X. A `gridX` of 0 fits as many whole cells as `drawerX` holds;
    /// with a drawer under one cell that is 0, which validation (not this type) prevents.
    public var cellsX: Int { c.gridX == 0 ? Int((c.drawerX / d.lGrid).rounded(.down)) : c.gridX }
    /// gy
    public var cellsY: Int { c.gridY == 0 ? Int((c.drawerY / d.lGrid).rounded(.down)) : c.gridY }

    /// dx: the plate length along X, the grid less its clearance or the drawer, whichever is larger.
    public var width: Double { max(Double(cellsX) * d.lGrid - b.bpXYClearance, c.drawerX) }
    /// dy
    public var depth: Double { max(Double(cellsY) * d.lGrid - b.bpXYClearance, c.drawerY) }

    /// `calculate_off`: how far the plate extends below z = 0.
    ///
    /// OpenSCAD's function reads the file-level `screw_together` (from the global
    /// `style_plate`), not its `sp` argument. The file always passes `style_plate` as `sp`, so
    /// both are the configuration's plate style here.
    ///
    /// For the skeletonized style without screw holes, OpenSCAD adds `d_screw` (the screw
    /// diameter, 3.35) as a floor height, where the other hole styles add the countersink or
    /// counterbore depth. The port keeps that.
    public var floorDepth: Double {
        if screwTogether { return 6.75 }
        switch c.plateStyle {
        case .thin:
            return 0
        case .weighted:
            return b.bpHBot
        case .skeletonized, .screwTogether, .screwTogetherMinimal:
            let hole: Double = switch c.screwHoles {
            case .none: c.screwDiameter
            case .countersink: b.dCs
            case .counterbore: b.hCb
            }
            return b.hSkel + (c.magnetHoles ? d.hHole : 0) + hole
        }
    }

    /// offsetx: how far the plate body moves along X, so the extra drawer length sits on the
    /// side `fitX` chooses. The grid of sockets stays centered on the origin.
    public var offsetX: Double {
        c.drawerX < width ? 0 : (Double(cellsX) * d.lGrid - b.bpXYClearance - c.drawerX) / 2 * c.fitX * -1
    }
    /// offsety
    public var offsetY: Double {
        c.drawerY < depth ? 0 : (Double(cellsY) * d.lGrid - b.bpXYClearance - c.drawerY) / 2 * c.fitY * -1
    }

    /// The plate in OpenSCAD's placement (`gridfinityBaseplate`, lines 83 to 117).
    public func geometry() -> any Geometry3D {
        let off = floorDepth
        let body = roundedRectangle(length: width, width: depth, height: d.hBase + off, radius: d.rBase)
            .flipped(along: .z)
            .translated(x: offsetX, y: offsetY, z: d.hBase)
        let sockets = d.gridfinityBase(
            gridX: Double(cellsX), gridY: Double(cellsY), length: d.lGrid,
            divisionX: 1, divisionY: 1, styleHole: 0, offset: 0.5, finalCut: false
        )
        // The sockets reach z = 10.996 (offset 0.5, no final cut); this trim sets the plate top.
        let topTrim = roundedRectangle(length: width * 2, width: depth * 2, height: d.hBase * 2, radius: d.rBase)
            .translated(x: offsetX, y: offsetY, z: d.hBase - 0.6)
        let cells = patternLinear(x: cellsX, y: cellsY, spacingX: d.lGrid, cellCutter(floorDepth: off))

        return body.subtracting {
            sockets
            topTrim
            cells
            if screwTogether {
                // The channels sit at the grid edge (`gx * l_grid / 2`), not at the plate edge.
                // When the drawer pads the plate beyond the grid, they end inside the padding and
                // do not open at the plate edge. The port keeps that.
                cutters.screwTogether(
                    gridX: cellsX, gridY: cellsY, offset: off,
                    screwDiameter: c.screwDiameter, screwHeadDiameter: c.screwHeadDiameter,
                    screwSpacing: c.screwSpacing, screwCount: c.screwsPerCell
                )
            }
        }
    }

    /// The per-cell cutter of `gridfinityBaseplate` (lines 94 to 114): the style's floor cut
    /// and the hole pattern of magnet and screw holes. OpenSCAD wraps it in
    /// `render(convexity = 6)`, which does not change the shape and has no port. As in
    /// OpenSCAD, the thin style cuts the hole pattern too.
    func cellCutter(floorDepth off: Double) -> any Geometry3D {
        let extrusion = 10 * (d.hBase + off)
        let holes: any Geometry3D = Union {
            if c.magnetHoles {
                d.blockBaseHole(style: 1)
            }
            if c.screwHoles == .countersink {
                cutters.countersink().translated(z: -off)
            } else if c.screwHoles == .counterbore {
                cutters.counterbore().translated(z: -off)
            }
        }
        return Union {
            if c.plateStyle == .weighted {
                cutters.weight().translated(z: -off)
            } else if c.plateStyle == .skeletonized || c.plateStyle == .screwTogether {
                cutters.skeletonProfile().extruded(height: extrusion).aligned(at: .centerZ)
            } else if c.plateStyle == .screwTogetherMinimal {
                roundedSquare(length: d.lGrid - 2 * d.rC2 - 2 * d.rC1, height: extrusion, radius: d.rFo3)
                    .translated(z: -5 * (d.hBase + off))
            }
            cutters.holePattern(holes)
        }
    }
}
