# GridfinityCustomizers

Customizers for the standard Gridfinity components, written in Swift with
[Cadova](https://github.com/tomasf/Cadova). Each component is meant to be its own web customizer
page. The baseplate is first; the bin, the lite bin and the spiral vase bin are planned.

- `GridfinityModels`, the library: the baseplate model (`BaseplateConfiguration`,
  `BaseplateDesign`), the customizer's input with its defaults (`BaseplateInput`) and its ranges
  (`BaseplateLimits`).
- `gridfinity-baseplate`, the executable: the baseplate customizer page's project.

## The baseplate page

A port of `gridfinity-rebuilt-baseplate.scad`. The page has one model, "Baseplate", made of one
part named "Baseplate". The download is placed with its lowest point at z = 0, on the bed. The
page's description reports the resulting plate, for example "Plate: 5 x 5 cells, 209.5 x 209.5 mm"
for the defaults.

The controls, in the order the page lists them. Every default comes from `BaseplateInput.defaults`
and every range from `BaseplateLimits`.

| Control | Shown | Range | Default | OpenSCAD |
|---|---|---|---|---|
| Plate style | always | Thin, Weighted, Skeletonized, Screw together, Screw together minimal | Thin | `style_plate` |
| Size by | always | Grid cells, Drawer size | Grid cells | |
| Grid width | Grid cells | 1 to 10 cells | 5 | `gridx` |
| Grid depth | Grid cells | 1 to 10 cells | 5 | `gridy` |
| Drawer width | Drawer size | 42 to 420 mm | 210 | `distancex` |
| Drawer depth | Drawer size | 42 to 420 mm | 210 | `distancey` |
| Align width | Drawer size | -1 to 1, step 0.1 | 0 | `fitx` |
| Align depth | Drawer size | -1 to 1, step 0.1 | 0 | `fity` |
| Magnet holes | styles with a floor | on, off | on | `enable_magnet` |
| Screw holes | styles with a floor | None, Countersink, Counterbore | Counterbore | `style_hole` |
| Screw diameter | screw together styles | 1.5 to 6 mm | 3.35 | `d_screw` |
| Screw head diameter | screw together styles | 3 to 12 mm | 5 | `d_screw_head` |
| Screw spacing | screw together styles | 0 to 3 mm | 0.5 | `screw_spacing` |
| Screws per cell | screw together styles | 1 to 3 | 1 | `n_screws` |
| Color | always | any color | #C8CDD6 (light grey) | |

The styles with a floor are Weighted, Skeletonized, Screw together and Screw together minimal. In
Drawer size mode the plate holds as many whole 42 mm cells as fit in the drawer and is padded to
the drawer size; the two Align controls decide where the padding goes. The page does not limit
the plate to a printer bed: a plate larger than the bed is meant to be printed in parts.

## License and credits

MIT, see `LICENSE`. Original Gridfinity system by Zachary Freedman and Voidstar Lab LLC. Baseplate
design from [gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad)
by Kenneth Hodson (MIT). This is a port to Swift and Cadova by David Green. `LICENSE` reproduces
the licenses of gridfinity-rebuilt-openscad and of Gridfinity.

## Dependencies

- [Cadova](https://github.com/tomasf/Cadova) 1.3.0 or later.
- `../GridfinityRebuilt`, the shared library (a path dependency). Its `GridfinityTestSupport`
  product is used by the tests.

## Build and test

```
swift build
swift test
swift run gridfinity-baseplate
```

`swift run gridfinity-baseplate` writes `Models/Baseplate.3mf` for the default plate (5 x 5 cells,
thin, 209.5 x 209.5 x 4.4 mm).

`Tests/GridfinityModelsTests/CatalogTests.swift` runs the built executable
(`.build/debug/gridfinity-baseplate`) the way the web customizer does, with
`CADOVA_CUSTOMIZER_REQUEST`, and checks the controls it lists for each plate style and sizing mode,
their defaults, ranges and order, the page text, and the downloaded 3MF. `swift test` does not
build the executable, so run `swift build` before `swift test` after changing `main.swift`.

The two benchmark tests in `BuildTimeTests.swift` are skipped unless `GRIDFINITY_BENCH=1` is set.

## Reference models

The reference harness runs the original OpenSCAD baseplate file and records each case's volume and
bounding box in `Reference/reference.json`, plus an STL per case. OpenSCAD is required, and the
original source is expected at `../../Lidded Bins/gridfinity-rebuilt-openscad/` relative to this
directory.

```
python3 -I Reference/generate.py            # all cases
python3 -I Reference/generate.py thin_2x2   # one case
```

`Reference/stl` is git-ignored.

## Web customizer pages

The web customizer pages are built by the repository workflow.
