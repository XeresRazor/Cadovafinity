import Foundation
import Cadova
import GridfinityModels

// The web customizer's project. Built natively (`swift run gridfinity-baseplate`), every parameter
// has its default value, so this writes `Models/Baseplate.3mf` for the default plate.
//
// The page lists a parameter only when the build reads it, in the order the reads happen. The
// parameters are declared in the project body, where a declaration alone lists nothing, and read
// only when they matter:
// - the grid cell counts only when sizing by grid cells, the drawer size and its alignment only
//   when sizing by drawer;
// - the magnet and screw holes only for the plate styles that have a floor to cut them into;
// - the screw-together settings only for the two screw together styles.
//
// Every default comes from `BaseplateInput.defaults`, and every range from `BaseplateLimits`.

let defaults = BaseplateInput.defaults

/// A length in mm as the page shows it: up to two decimals, without trailing zeros.
func millimeters(_ value: Double) -> String {
    var text = String(format: "%.2f", value)
    while text.hasSuffix("0") { text.removeLast() }
    if text.hasSuffix(".") { text.removeLast() }
    return text
}

await Project(packageRelative: "Models") {
    @Parameter("Plate style", description: "The kind of plate (style_plate). Thin has no floor; weighted adds a floor with weight pockets; skeletonized cuts the floor away around the holes; the two screw together styles add screw channels for joining plates.")
    var plateStyle = defaults.plateStyle

    @Parameter("Size by", description: "Set the plate size by a number of grid cells, or by the size of the drawer it should fill")
    var sizing = defaults.sizing

    @Parameter("Grid width", in: BaseplateLimits.gridSize, unit: "cells",
               description: "Plate width in 42 mm Gridfinity cells (gridx)")
    var gridX = defaults.gridX

    @Parameter("Grid depth", in: BaseplateLimits.gridSize, unit: "cells",
               description: "Plate depth in 42 mm Gridfinity cells (gridy)")
    var gridY = defaults.gridY

    @Parameter("Drawer width", in: BaseplateLimits.drawerSize, unit: "mm",
               description: "Minimum plate length along X (distancex). The plate is at least this long, so enter slightly less than the drawer's inside width for a loose fit.")
    var drawerX = defaults.drawerX

    @Parameter("Drawer depth", in: BaseplateLimits.drawerSize, unit: "mm",
               description: "Minimum plate length along Y (distancey). The plate is at least this long, so enter slightly less than the drawer's inside depth for a loose fit.")
    var drawerY = defaults.drawerY

    @Parameter("Align width", in: BaseplateLimits.fit, step: 0.1,
               description: "Where the extra space along the width goes (fitx): -1 puts it all on one side, 0 splits it evenly, 1 puts it all on the other side")
    var fitX = defaults.fitX

    @Parameter("Align depth", in: BaseplateLimits.fit, step: 0.1,
               description: "Where the extra space along the depth goes (fity): -1 puts it all on one side, 0 splits it evenly, 1 puts it all on the other side")
    var fitY = defaults.fitY

    @Parameter("Magnet holes", description: "Magnet holes in the floor under each cell (enable_magnet)")
    var magnetHoles = defaults.magnetHoles

    @Parameter("Screw holes", description: "The screw hole through the floor at each hole position (style_hole)")
    var screwHoles = defaults.screwHoles

    @Parameter("Screw diameter", in: BaseplateLimits.screwDiameter, unit: "mm",
               description: "Diameter of the screw channels that join plates (d_screw). The default fits M3 and 4-40 screws.")
    var screwDiameter = defaults.screwDiameter

    @Parameter("Screw head diameter", in: BaseplateLimits.screwHeadDiameter, unit: "mm",
               description: "Diameter of the screw heads (d_screw_head), used to space the screws of one cell")
    var screwHeadDiameter = defaults.screwHeadDiameter

    @Parameter("Screw spacing", in: BaseplateLimits.screwSpacing, unit: "mm",
               description: "The gap between the screw heads of one cell (screw_spacing)")
    var screwSpacing = defaults.screwSpacing

    @Parameter("Screws per cell", in: BaseplateLimits.screwsPerCell, unit: "screws",
               description: "Screw channels per cell along each plate edge (n_screws)")
    var screwsPerCell = defaults.screwsPerCell

    @Parameter("Color", description: "The color of the plate in the downloaded 3MF. It does not change the geometry.")
    var color = defaults.color

    // The reads, in the order the page lists the controls

    var input = defaults
    input.plateStyle = plateStyle
    input.sizing = sizing

    switch sizing {
    case .gridCells:
        input.gridX = gridX
        input.gridY = gridY
    case .drawer:
        input.drawerX = drawerX
        input.drawerY = drawerY
        input.fitX = fitX
        input.fitY = fitY
    }

    // Only a plate with a floor has room for magnet and screw holes
    if plateStyle != .thin {
        input.magnetHoles = magnetHoles
        input.screwHoles = screwHoles
    }

    if plateStyle == .screwTogether || plateStyle == .screwTogetherMinimal {
        input.screwDiameter = screwDiameter
        input.screwHeadDiameter = screwHeadDiameter
        input.screwSpacing = screwSpacing
        input.screwsPerCell = screwsPerCell
    }

    let design = BaseplateDesign(input.configuration)

    Metadata(
        title: "Gridfinity Baseplate",
        description: """
        A Gridfinity baseplate: the grid of sockets that Gridfinity bins sit in. Size it by a \
        number of cells or to fill a drawer, and choose a thin plate or one with a floor that \
        holds magnets, screws and weights, or screw channels that join several plates.

        Plate: \(design.cellsX) x \(design.cellsY) cells, \(millimeters(design.width)) x \
        \(millimeters(design.depth)) mm

        Original Gridfinity system by Zachary Freedman and Voidstar Lab LLC. Baseplate design \
        from gridfinity-rebuilt-openscad by Kenneth Hodson. This is a port to Swift and Cadova.
        """,
        author: "David Green (port)",
        license: "MIT"
    )

    await Model("Baseplate") {
        // The design puts the plate's top at z = 4.4 and its bottom at -floorDepth, as the
        // OpenSCAD original does; the download sits on the bed at z = 0.
        design.geometry()
            .translated(z: design.floorDepth)
            .inPart(name: "Baseplate", color: color)
    }
}
