# Cadovafinity

A Gridfinity bin with a sliding lid that you can adjust in a web page, built with Swift and [Cadova](https://cadova.org).

**Web customizer: <https://xeresrazor.github.io/Cadovafinity/>**

Pick the grid size, height, compartments, finger grips and lid direction, tune the lid fit, watch the 3D preview, and download the bin, the lid or both as 3MF files for your slicer.

The design is a port of smkent's OpenSCAD model "Gridfinity Bins with Lids" to Swift. The geometry is checked against the original OpenSCAD output, with a few deliberate changes listed below.

## What you can adjust

- Grid width and depth (1 to 6 cells), and the height as 7 mm units (from 2 units), internal height or overall height.
- Compartment layout: an equal grid, or compartments of two sizes. Compartments X and Y set the number of compartments along each axis: 1 is a single open compartment, and 2 is the smallest count that adds a divider (N compartments have N minus 1 dividers).
- Lip grips (none, along X, along Y, both), lid direction (four ways) and the interior style: Minimal, Partially raised, or Flush raised for a flat floor.
- Five downloads: **Bin**, **Lid**, **Bin and lid (closed)**, **Bin and lid (separated)** (side by side on the build plate, ready to import into a slicer) and **Bin and lid (open)**.
- Colors for multi-color or multi-filament printing: four color pickers (bin, dividers, lid rim and lip, lid center). Each model downloads as separate named parts in the 3MF, so a slicer can print the dividers or the lid rim in their own color.
- Lid fit, in three controls with their original-model equivalents in the page and the READMEs:
  - **Lid clearance:** the gap between the lid and the slot on each side (default 0.20 mm).
  - **Lid chamfer:** the rise of the slot roof, and the lid's edge chamfer that follows it (default 1.4 mm).
  - **Detent interference:** how firmly the bump on the bin catches the lid (default 0.25 mm).

The fit defaults are starting values chosen from measurements of the model, then checked in cross-section. How the lid feels depends on your printer, so expect to adjust them after a test print.

## Differences from the original

- The customizer offers heights from 2 units. A 1 unit bin does not work in the original model either: its compartments end below the top of the interior base grid and are sealed under a solid top.
- The customizer offers 1 to 12 compartments per axis. The original model's `divx` and `divy` of 0 (a solid block) is not offered.
- The bin slice (`binSlice`) is a hollow ring. The original OpenSCAD model produces a solid block there because of an empty-children quirk.
- The lid fit is tighter, the slot roof and lid chamfer are larger, and the detent is a seated catch. The `openSCADOriginal` preset in the code reproduces the original geometry exactly, and the reference tests use it.
- The custom compartment pattern, which needs editing the source, is not included. The web page cannot offer it.
- The Flush raised interior style, a flat floor at the top of the base feet, is an addition. The original offers Minimal and Partially raised.

## Repository

| Folder | Contents |
|---|---|
| [`LiddedBin/`](LiddedBin/README.md) | The lidded bin: model library, the `lidded-bin` executable that defines the customizer, and the OpenSCAD reference generator. 120 tests. |
| [`GridfinityRebuilt/`](GridfinityRebuilt/README.md) | A Swift/Cadova port of the core of [gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad), plus `GridfinityTestSupport`, the helpers that compare geometry with OpenSCAD output. 33 tests. |
| `docs/superpowers/` | Design notes, specs and implementation plans. |
| `.github/workflows/customizer.yml` | Builds the customizer and publishes it to GitHub Pages on every push to `main`. |

## Build and test

Requires macOS 15 and Swift 6.3 (the packages use `swift-tools-version: 6.3`).

```
cd LiddedBin
swift build
swift run lidded-bin        # writes the Bin, Lid and open assembly 3MF files to Models/
swift test
```

Tests that compare against OpenSCAD need [OpenSCAD](https://openscad.org) installed. Generate the reference meshes once with `python3 -I Reference/generate.py` in `LiddedBin` (and in `GridfinityRebuilt`); the generated STL files are git-ignored. See each package's README for details.

To build the customizer page locally you need the Swift 6.4.0 toolchain from swift.org, then `swift package generate-customizer` in `LiddedBin`. The GitHub workflow does this on every push to `main`.

## Licenses and credits

- **LiddedBin** is a port of "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 (Printables), licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). See `LiddedBin/LICENSE` for the attribution and the list of changes.
- **GridfinityRebuilt** is MIT licensed, and its `LICENSE` carries the notices of gridfinity-rebuilt-openscad (Kenneth Hodson) and of Gridfinity (Zachary Freedman and Voidstar Lab LLC).
- [Cadova](https://github.com/tomasf/Cadova) and its dependencies are listed on the customizer page under its licenses link.

Ported by David Green.
