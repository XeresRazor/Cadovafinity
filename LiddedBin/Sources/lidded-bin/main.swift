import Cadova
import LiddedBinModel

// The web customizer's project. Built natively (`swift run lidded-bin`), every parameter has its
// default value, so this writes the five models for the default bin.
//
// Where a parameter is read decides which tabs list it. Cadova lists a parameter on every tab when
// the project's own content reads it, and on a model's tab when that model reads it. So:
// - the settings both the bin and the lid depend on (size, height, lid direction, lip grips, and
//   the three lid fit controls) are read in the project body and appear on every tab;
// - the bin-only settings (interior style, compartment layout, compartment counts, size multiple) are declared in
//   the project body, so the Bin and assembly tabs share their values, but are read only
//   inside those models, so the Lid tab does not list them;
// - the four part colors are declared in the project body and read only by the models that have
//   those parts: the Bin tab lists the bin and divider colors, the Lid tab the two lid colors,
//   and the assembly tabs all four. They only color the parts and do not change the geometry.
// A declaration alone does not list a parameter; only reading it does. The conditional
// parameters rely on that: they are read only when they matter.
//
// Every default comes from `LiddedBinInput.defaults`, and the colors from
// `LiddedBinColors.defaults`.

let defaults = LiddedBinInput.defaults
let defaultColors = LiddedBinColors.defaults

await Project(packageRelative: "Models") {
    Metadata(
        title: "Gridfinity Lidded Bin",
        description: """
        A Gridfinity bin with a sliding lid, with optional dividers, finger grips and a choice of \
        lid direction.

        Original OpenSCAD design: "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 \
        (Printables), CC BY 4.0. This is a port to Swift and Cadova.
        """,
        author: "smkent (original design), ported by David Green",
        license: "CC BY 4.0"
    )

    // Layout

    @Parameter("Grid width", in: LiddedBinLimits.gridSize, unit: "cells",
               description: "Bin width in 42 mm Gridfinity cells (gridx)")
    var gridX = defaults.gridX

    @Parameter("Grid depth", in: LiddedBinLimits.gridSize, unit: "cells",
               description: "Bin depth in 42 mm Gridfinity cells (gridy)")
    var gridY = defaults.gridY

    // Height

    @Parameter("Height style", description: "What the height value means (gridz_define)")
    var heightStyle = defaults.heightStyle

    // One declaration for both millimeter styles, so they share one value
    @Parameter("Snap to 7 mm", description: "Round the height up to a multiple of 7 mm (enable_zsnap)")
    var snapHeight = defaults.snapHeight

    @Parameter("Internal block height", in: 0.0...80.0, unit: "mm",
               description: "Overrides the internal block height of the bin for solid containers; leave 0 for the default (height_internal)")
    var internalBlockHeight = defaults.internalBlockHeight

    // Lid

    @Parameter("Lid direction", description: "The side the lid slides out towards (Lid_Orientation)")
    var lidOrientation = defaults.lidOrientation

    @Parameter("Lip grips", description: "Finger grips cut into the lid lip (Lip_Grips)")
    var lipGrips = defaults.lipGrips

    @Parameter("Lid clearance", in: LiddedBinLimits.lidClearance, step: 0.05, unit: "mm",
               description: "The gap between the lid and the slot on each side. Smaller is a tighter fit; the original model used 0.45.")
    var lidClearance = defaults.lidClearance

    @Parameter("Lid chamfer", in: LiddedBinLimits.lidChamfer, step: 0.1, unit: "mm",
               description: "The rise of the bin's slot roof, the slope that holds the lid down. The lid's edge chamfer follows it, about 0.6 times as tall. Original: 0.8.")
    var lidChamfer = defaults.lidChamfer

    @Parameter("Detent interference", in: LiddedBinLimits.detentInterference, step: 0.05, unit: "mm",
               description: "How far the bump on the bin overlaps the lid's edge as the lid slides past it. More is a firmer click and a stiffer lid; the original model used 0.15.")
    var detentInterference = defaults.detentInterference

    // Colors: each model is made of named parts in these colors, so a slicer can print them in
    // different filaments

    @Parameter("Bin color", description: "The color of the bin body: the outer wall, the lid slot, the floor and the feet")
    var binColor = defaultColors.binBody

    @Parameter("Divider color", description: "The color of the dividers between the compartments")
    var dividerColor = defaultColors.dividers

    @Parameter("Lid rim color", description: "The color of the lid's raised rim and the lip that slides in the bin's slot")
    var lidRimColor = defaultColors.lidRim

    @Parameter("Lid center color", description: "The color of the flat center of the lid")
    var lidCenterColor = defaultColors.lidCenter

    // Bin only: declared here so that the Bin and assembly tabs share them, read only in
    // those two models

    @Parameter("Interior style", description: "The shape of the bin floor (Interior_Style)")
    var interiorStyle = defaults.interiorStyle

    @Parameter("Compartment layout", description: "An equal grid, or compartments of two sizes (div_pattern)")
    var compartmentPattern = defaults.compartmentPattern

    @Parameter("Compartments X", in: LiddedBinLimits.dividers, unit: "compartments",
               description: "Number of compartments along X (divx). 1 is a single open compartment; each extra compartment adds a divider. 0 gives the same open bin.")
    var divX = defaults.divX

    @Parameter("Compartments Y", in: LiddedBinLimits.dividers, unit: "compartments",
               description: "Number of compartments along Y (divy). 1 is a single open compartment; each extra compartment adds a divider. 0 gives the same open bin.")
    var divY = defaults.divY

    @Parameter("Size multiple", in: LiddedBinLimits.divMultiple, step: 0.5,
               description: "Size of the secondary compartments, as a multiple of the primary ones (div_multiple)")
    var divMultiple = defaults.divMultiple

    // The shared settings, read in the project body so that every tab lists them, in this order

    var shared = defaults
    shared.gridX = gridX
    shared.gridY = gridY
    shared.heightStyle = heightStyle

    // Each height control is declared in the case of its style, so only the active one is listed
    switch heightStyle {
    case .sevenMillimeterUnits:
        @Parameter("Height", in: LiddedBinLimits.unitsHeight, step: 1, unit: "units",
                   description: "Bin height in 7 mm Gridfinity units (gridz)")
        var unitsHeight = defaults.unitsHeight
        shared.unitsHeight = unitsHeight
    case .internalHeight:
        @Parameter("Internal height", in: LiddedBinLimits.internalHeight, step: 1, unit: "mm",
                   description: "Height inside the bin in millimeters (gridz)")
        var internalHeight = defaults.internalHeight
        shared.internalHeight = internalHeight
        shared.snapHeight = snapHeight
    case .externalHeight:
        @Parameter("Overall height", in: LiddedBinLimits.externalHeight, step: 1, unit: "mm",
                   description: "Overall outside height of the bin in millimeters (gridz)")
        var externalHeight = defaults.externalHeight
        shared.externalHeight = externalHeight
        shared.snapHeight = snapHeight
    }

    shared.internalBlockHeight = internalBlockHeight
    shared.lidOrientation = lidOrientation
    shared.lipGrips = lipGrips
    // The lid fit: the clearance sets the lid's size and, with the interference, how far the
    // detent bumps on the bin protrude; the chamfer shapes the slot roof and the lid's tongue.
    // Both parts depend on all three.
    shared.lidClearance = lidClearance
    shared.lidChamfer = lidChamfer
    shared.detentInterference = detentInterference

    let lidInput = shared

    // The bin's settings: the shared ones plus the bin-only ones. Called only inside the models
    // that need them, so only their tabs list the bin-only parameters.
    let binInput: @Sendable () -> LiddedBinInput = {
        var input = lidInput
        input.interiorStyle = interiorStyle
        input.compartmentPattern = compartmentPattern
        input.divX = divX
        input.divY = divY
        if input.compartmentPattern == .multiSize {
            input.divMultiple = divMultiple
        }
        return input
    }

    // The colors of each model, read only inside the models that have those parts
    let binColors: @Sendable () -> LiddedBinColors = {
        var colors = defaultColors
        colors.binBody = binColor
        colors.dividers = dividerColor
        return colors
    }
    let lidColors: @Sendable () -> LiddedBinColors = {
        var colors = defaultColors
        colors.lidRim = lidRimColor
        colors.lidCenter = lidCenterColor
        return colors
    }
    let allColors: @Sendable () -> LiddedBinColors = {
        LiddedBinColors(binBody: binColor, dividers: dividerColor,
                        lidRim: lidRimColor, lidCenter: lidCenterColor)
    }

    await Model("Bin") {
        LiddedBinDesign(binInput().configuration).coloredGeometry(for: .bin, colors: binColors())
    }
    await Model("Lid") {
        LiddedBinDesign(lidInput.configuration).coloredGeometry(for: .lidOnPlate, colors: lidColors())
    }
    await Model("Bin and lid (closed)") {
        LiddedBinDesign(binInput().configuration).coloredGeometry(for: .bothClosed, colors: allColors())
    }
    await Model("Bin and lid (separated)") {
        LiddedBinDesign(binInput().configuration).coloredGeometry(for: .bothSeparated, colors: allColors())
    }
    await Model("Bin and lid (open)") {
        LiddedBinDesign(binInput().configuration).coloredGeometry(for: .bothOpen, colors: allColors())
    }
}
