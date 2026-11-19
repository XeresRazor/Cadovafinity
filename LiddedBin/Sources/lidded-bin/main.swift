import Cadova
import LiddedBinModel

// The web customizer's project. Built natively (`swift run lidded-bin`), every parameter has its
// default value, so this writes the three models for the default bin.
//
// Where a parameter is read decides which tabs list it. Cadova lists a parameter on every tab when
// the project's own content reads it, and on a model's tab when that model reads it. So:
// - the settings both the bin and the lid depend on (size, height, lid direction, lip grips) are
//   read in the project body and appear on every tab;
// - the bin-only settings (interior style, compartments, dividers, size multiple) are declared in
//   the project body, so the Bin and open assembly tabs share their values, but are read only
//   inside those two models, so the Lid tab does not list them.
// A declaration alone does not list a parameter; only reading it does. The conditional
// parameters rely on that: they are read only when they matter.
//
// Every default comes from `LiddedBinInput.defaults`.

let defaults = LiddedBinInput.defaults

await Project(packageRelative: "Models") {
    Metadata(
        title: "Gridfinity Lidded Bin",
        description: """
        A Gridfinity bin with a sliding lid, with optional dividers, finger grips and a choice of \
        lid direction.

        Original OpenSCAD design: "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 \
        (Printables), CC BY 4.0. This is a port to Swift and Cadova.
        """,
        author: "smkent (original design), ported by XeresRazor",
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
               description: "Side gap between the lid and the slot; smaller fits closer (original model: 0.45)")
    var lidClearance = defaults.lidClearance

    @Parameter("Lid chamfer", in: LiddedBinLimits.lidChamfer, step: 0.1, unit: "mm",
               description: "Height of the slot roof slope and the matching chamfer on the lid's top edge; larger is steeper and easier to see (original model: 0.8)")
    var lidChamfer = defaults.lidChamfer

    // Bin only: declared here so that the Bin and open assembly tabs share them, read only in
    // those two models

    @Parameter("Interior style", description: "The shape of the bin floor (Interior_Style)")
    var interiorStyle = defaults.interiorStyle

    @Parameter("Compartments", description: "An equal grid, or compartments of two sizes (div_pattern)")
    var compartmentPattern = defaults.compartmentPattern

    @Parameter("Dividers X", in: LiddedBinLimits.dividers,
               description: "Compartments along X (divx); 0 gives one open compartment with no dividers")
    var divX = defaults.divX

    @Parameter("Dividers Y", in: LiddedBinLimits.dividers,
               description: "Compartments along Y (divy); 0 gives one open compartment with no dividers")
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

    // The clearance is read only where the lid is built, so the Bin tab does not list it. The
    // chamfer shapes both the slot roof and the lid, so all three models read it.
    let withClearance: @Sendable (LiddedBinInput, Double) -> LiddedBinInput = { input, clearance in
        var input = input
        input.lidClearance = clearance
        return input
    }
    let withChamfer: @Sendable (LiddedBinInput, Double) -> LiddedBinInput = { input, chamfer in
        var input = input
        input.lidChamfer = chamfer
        return input
    }

    await Model("Bin") {
        LiddedBinDesign(withChamfer(binInput(), lidChamfer).configuration).geometry(for: .bin)
    }
    await Model("Lid") {
        LiddedBinDesign(withChamfer(withClearance(lidInput, lidClearance), lidChamfer).configuration)
            .geometry(for: .lid)
    }
    await Model("Bin and lid (open)") {
        LiddedBinDesign(withChamfer(withClearance(binInput(), lidClearance), lidChamfer).configuration)
            .geometry(for: .bothOpen)
    }
}
