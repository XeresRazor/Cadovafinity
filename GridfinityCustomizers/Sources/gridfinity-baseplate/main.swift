import Cadova

await Project(packageRelative: "Models") {
    await Model("Baseplate") {
        Box(1)
    }
}
