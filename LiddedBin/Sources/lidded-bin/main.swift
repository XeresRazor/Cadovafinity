import Cadova
import LiddedBinModel

let design = LiddedBinDesign(LiddedBinConfiguration())

await Project(packageRelative: "Models") {
    Metadata(
        title: "Gridfinity Lidded Bin",
        description: "A Gridfinity bin with a sliding lid. Port of smkent's OpenSCAD design.",
        author: "smkent (original design)",
        license: "CC BY 4.0"
    )
    await Model("Bin") { design.geometry(for: .bin) }
    await Model("Lid") { design.geometry(for: .lid) }
    await Model("Bin and lid, closed") { design.geometry(for: .bothClosed) }
    await Model("Bin and lid, open") { design.geometry(for: .bothOpen) }
    await Model("Bin slice") { design.geometry(for: .binSlice) }
}
