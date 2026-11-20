# LiddedBin

A Swift/Cadova model of a Gridfinity bin with a sliding lid. It is a port of the OpenSCAD design
`lid-bin.scad`, and its output is checked against OpenSCAD's own output for the same settings.

## Attribution and license

This is a port of "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 (Printables). The
header of the original `lid-bin.scad` reads:

> Gridfinity Bins with Lids. By smkent (GitHub) / bulbasaur0 (Printables).
> Licensed under Creative Commons (4.0 International License) Attribution

The original is licensed under CC BY 4.0: <https://creativecommons.org/licenses/by/4.0/>.

This package is a port with changes: it is written in Swift with Cadova instead of OpenSCAD, and
the custom compartment pockets feature was dropped (see "Known differences"). Models exported by
`lidded-bin` carry the metadata author "smkent (original design), ported by David Green" and
license "CC BY 4.0", and the metadata description names the original design and its license.

## Dependency

The bin body is built on `../GridfinityRebuilt`, a port of
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad), which is
released under the MIT License (stated on its GitHub page). The OpenSCAD copy next to
`lid-bin.scad` contains only `.scad` files, so the license text is not in that copy.

`LiddedBin` also depends on [Cadova](https://github.com/tomasf/Cadova) (1.3.0 or later).
`d_wall` is 1.6 mm throughout, as `lid-bin.scad` sets it, so the design uses
`Dimensions.dWall = 1.6`.

## Configuration

`LiddedBinConfiguration` holds the user-facing settings. The names in the second column are the
variables in `lid-bin.scad`.

| Swift property | lid-bin.scad | Default |
|---|---|---|
| `gridX` | `gridx` | 2 |
| `gridY` | `gridy` | 2 |
| `gridZ` | `gridz` | 3 |
| `heightMode` | `gridz_define` | `.units` |
| `snapHeight` | `enable_zsnap` | false |
| `internalHeightOverride` | `height_internal` | 0 |
| `interiorStyle` (`minimal`, `partialRaised`, `flushRaised`) | `Interior_Style` (`flushRaised` is not in lid-bin.scad; see "Interior styles") | `minimal` |
| `lipGrips` (`none`, `x`, `y`, `xy`) | `Lip_Grips` | `xy` |
| `lidOrientation` (`up`, `down`, `left`, `right`) | `Lid_Orientation` | `left` |
| `compartmentPattern` (`grid`, `multiSize`) | `div_pattern` (`default`, `multisize`) | `grid` |
| `divX` | `divx`: the number of compartments along X (N compartments have N - 1 dividers) | 6 |
| `divY` | `divy`: the number of compartments along Y | 6 |
| `divMultiple` | `div_multiple` (clamped to 1...5) | 2 |
| `lidClearance` | side gap between lid and slot (`0.5 + 3 * lid_hfit_tolerance` inset, 0.45 per side) | 0.20 (original-equivalent 0.45; clamped to 0.10...0.6) |
| `lidChamfer` | rise of the slot roof, the slope that holds the lid down; the lid's edge chamfer follows it, about 0.6 times as tall | 1.4 (original-equivalent 0.8; clamped to 0.8...1.8) |
| `detentInterference` | how far the bump on the bin overlaps the lid's edge as the lid slides past it | 0.25 (original-equivalent 0.15; clamped to 0.10...0.40) |
| `detentStyle` (`seated`, `original`; internal preset field, not in the customizer) | `seated` is the catch the lid snaps into; `original` is lid-bin.scad's round bump | `seated` (`original` in the original-equivalent preset) |
| `cornerSegments` | none | nil |

`cornerSegments` exists only to force the same corner tessellation as an OpenSCAD reference
built with a fixed `$fn`. Leave it nil in production.

`divMultiple` is clamped to 1...5, the range of `div_multiple` in the OpenSCAD customizer. Without
the clamp a value of 0 or less made the multisize pocket loops infinite.

The lid fit constants (`lid_wall_thickness`, `lid_thickness`, `lid_hfit_tolerance`,
`lid_vfit_tolerance`, `lid_vpos_tolerance`, `bin_separator_wall_thickness`,
`interior_base_wall_adjust`) live in the internal `LidFit` type with the original defaults. They
are not part of the public configuration; tests vary them through an internal initializer.

## Interior styles

The floor of each compartment sits on the Gridfinity base: one foot per grid cell, joined by a
slab. The tops of the feet end at `hBase + hBot / 2` = 6.1 mm, and the compartments (the pockets)
end at the pocket top, `storageHeight + 3.8` mm (19.8 mm for a 3 unit bin), 0.1 mm under the
lid's plate. The style decides how much of the inside of the feet stays hollow:

| Style | Floor of a compartment |
|---|---|
| Minimal (`minimal`) | The feet are hollow and open into the compartments, so each grid cell shows as a recess with sloped sides, its bottom at 2.01 mm. Between the cells the floor rises to ridges at 6.1 mm, and at the wall the slope reaches about 5.0 mm where the compartment ends. The pockets start at the wall line, 1.6 mm. |
| Partially raised (`partialRaised`) | The feet are solid up to 4.9 mm, so the recesses are 1.2 mm deep (4.9 to 6.1 mm), with the same ridges between them. The pockets start at 1.6 mm. |
| Flush raised (`flushRaised`) | The recesses are filled: the floor is one flat surface at the ridge height, `flushFloorHeight` = `hBase + hBot / 2` = 6.1 mm, everywhere inside the walls, and the dividers stand on it. The feet are solid up to that height and the pockets start there, so a 3 unit bin has compartments 13.7 mm deep. |

Flush raised changes only what lies under the flush floor: the walls, the lip, the lid slot, the
dividers above the floor and the outer shape of the base are those of the other styles, and the
lid is the same. A 2x2x3 bin with 2 by 1 compartments has 26123 mm^3 of material in Minimal,
40207 mm^3 in Partially raised and 46725 mm^3 in Flush raised.

Flush raised needs at least 2 mm (`minimumFlushDepth`) between the flush floor and the pocket top,
which holds from a storage height of 4.3 mm: the depth is 6.7 mm at 2 units and 13.7 mm at 3, and
every height the customizer offers in millimeters is deep enough. The 1 unit bin (storage height
2 mm, pocket top 5.8 mm, under the 6.1 mm floor) is built as Partially raised instead
(`effectiveInteriorStyle`). A flat floor cannot be lowered for it: between two feet the underside
of the base reaches up to 5.0 mm, so a floor that leaves 2 mm of depth (3.8 mm) would open slots
there.

In every style the pockets of a 1 unit bin end at 5.8 mm, under the top of the interior base grid
(7.7 mm), so its compartments are closed voids under a solid top that reaches into the lid's plate
(5.9 to 6.8 mm). lid-bin.scad builds the 1 unit bin the same way.

## Lid fit

Three lid fit controls of this port are not exposed by lid-bin.scad. Each has an
original-equivalent value. `LiddedBinConfiguration.openSCADOriginal` is a configuration with
every lid fit field set to that value (`lidClearance = 0.45`, `lidChamfer = 0.8`,
`detentInterference = 0.15` with `detentStyle = .original`, the original detent shape), and the
OpenSCAD reference tests build their designs from it.

`lidClearance` (mm) is the gap between the lid's edge and the slot face on each side. The
original inset `0.5 + 3 * lid_hfit_tolerance` fixes a gap of 0.45 mm per side.

- Default: 0.20 mm. Original-equivalent value: 0.45 mm.
- Effect: the plate and tongue are inset from the block outline by
  `0.5 + 2 * lid_wall_thickness + 2 * lidClearance`, so the vertical plate edge sits exactly
  `lidClearance` from the slot face. The offset around the tongue (`offset(delta = 0.30)` in the
  original) is derived as `min(0.30, lidClearance + 0.10)`: clearances of 0.20 and above keep the
  original 0.229 mm perpendicular gap between the tongue's chamfer and the slot roof, and smaller
  ones tighten it (0.129 mm at 0.10). The bin depends on it through the detent bumps, whose
  protrusion is `lidClearance + detentInterference`.
- Customizer: "Lid clearance" (0.10...0.6 mm, step 0.05) on all five tabs.
- The lid tongue peak depends on the clearance: a tighter clearance gives a taller tongue. With
  a lid chamfer of 1.4 the peak is 1.11 mm above the plate top at a clearance of 0.10 and 0.89 mm
  at 0.20.

`lidChamfer` (mm) is the rise of the slot roof: the slope from the slot face, at the top of the
lid plate, up and inward to where it meets the inside of the wall. The lid tongue's top outer
edge has a chamfer parallel to the roof, so it follows the same slope.

- Default: 1.4 mm. Original-equivalent value: 0.8 mm (the original 45 degree roof, which rises
  0.798 mm over a run of 0.798 mm and ends on the 45 degree underside of the stacking lip).
  Range: 0.8...1.8 mm.
- Effect: the run of a steeper roof is fixed by the wall. It ends on the stacking lip's vertical
  inner face, 0.7 mm in from the slot face (the inner face is not moved, since bins above stack
  on it), so the slope is `lidChamfer / 0.7`: about 63 degrees at 1.4 and 69 degrees at 1.8.
  Between 0.8 and 0.896 (where the roof first reaches the vertical face) the slope is
  interpolated, which keeps the rise within 0.003 mm of the setting. The tongue's chamfer keeps a perpendicular gap of
  0.229 mm (at the default clearance) to the roof for every rise, and the tongue's peak above
  the plate grows from 0.64 mm (0.8) to 0.89 mm (1.4).
- Customizer: "Lid chamfer" (0.8...1.8 mm, step 0.1) on all five tabs, since both the bin and
  the lid carry the slope.

`detentInterference` (mm) is how far the detent bumps on the bin overlap the lid's plate edge as
the lid slides past them. There is one bump on each side wall at the closed end, and a matching
notch in each side of the lid.

- Default: 0.25 mm. Original-equivalent value: 0.15 mm (the original bump protrudes 0.6 mm from
  the slot face against a 0.45 mm side gap). Range: 0.10...0.40 mm.
- Effect: the bump protrudes `lidClearance + detentInterference` from the slot face (0.45 mm by
  default), so the overlap stays the same when the clearance changes. In plan view the bump is
  a trapezoid: a 30 degree ramp (to the slide direction) on the side toward the open end, a
  0.8 mm flat top, and a 65 degree stop face on the side toward the closed end, which ends where
  the original bump ends. At the default protrusion the ramp runs 0.78 mm and the stop face
  0.21 mm, so the bump is 1.79 mm long, about the original 1.8. The notch in the lid is the bump
  grown by a 0.05 mm seat clearance all round, so in the closed position the bump nests in the
  notch with 0.05 mm of play across the slide direction (0.10 mm along it at the ramp and
  0.055 mm at the stop face) and the parts do not touch. A closing lid meets the gentle ramp
  first and the bump drops into the notch; opening, the notch's stop face has to climb the
  bump's steep stop face, which takes a definite push. The bump keeps the original height
  (z 19.75 to 22.85 for a 3 unit bin). Where it reaches above the slot roof it is inside the
  wall, and above the plate top it is clipped to the lip's inner face, which only affects
  protrusions over 0.7 mm. The original detent (`detentStyle = .original`) is the round bump
  0.6 mm deep with a notch 0.45 mm deeper than the bump, so a closed lid sits clear of it.
- The bumps sit where the lid plate's edge starts to curve into its corner, so while the lid
  slides the deepest overlap is 0.24 mm rather than the full 0.25 (measured on the straight
  edge), and the overlap ends about 1.85 mm after the lid starts to open.
- Customizer: "Detent interference" (0.10...0.40 mm, step 0.05) on all five tabs, since the bin
  carries the bumps and the lid the notches.

## Parts

`LiddedBinDesign(configuration).geometry(for:)` returns one of the `LiddedBinPart` values
(`Part` in `lid-bin.scad`):

| Part | Contents |
|---|---|
| `bin` | The bin. |
| `lid` | The lid, positioned as in OpenSCAD: its bottom is at z = -0.2 (lid_thickness less the vertical position tolerance). |
| `lidOnPlate` | The lid in print orientation (top up) with its lowest point at z = 0. `lid` is lifted by the vertical position tolerance (0.2 mm) to get this. The customizer's Lid tab uses it. |
| `bothClosed` | Bin and lid as two Cadova parts named "Bin" and "Lid", lid closed (seated in the slot). |
| `bothSeparated` | The same two parts side by side, each in print orientation and resting on the build plate at z = 0, with a 10 mm gap between their bounding boxes. The pair is centered on the origin along the layout direction (X when the grid is at most as wide as it is deep, Y otherwise) and each piece is centered on the other axis. The bin comes first (lower coordinate), then the lid. |
| `bothOpen` | The two parts as for `bothClosed`, with the lid slid open. |
| `binSlice` | A thin slice of the bin at the lip for print testing, a hollow ring. |

## Colors

`coloredGeometry(for:colors:)` returns the same models as `geometry(for:)`, placed the same way,
with each piece split into named Cadova parts that carry a color from `LiddedBinColors`. A slicer
can then give each part its own filament. The colors are presentation only: they do not change
the geometry and are not part of `LiddedBinConfiguration` or `LiddedBinInput`.

| Part | Contents | `LiddedBinColors` | Default |
|---|---|---|---|
| Bin body | The outer wall with the stacking lip and the lid slot, the detent bumps, the floor under the pockets, the base feet with the ridges between them, and the ring between the pockets and the wall | `binBody` | slate blue-grey `#587A9E` |
| Dividers | The walls between the compartments, from the pocket floor up (1.6 mm, or the 6.1 mm flush floor in the Flush raised style) | `dividers` | orange `#E8912D` |
| Lid rim and lip | The raised rim at the lid's open end, the tongue on top of the plate edge that slides under the slot roof, and the edge band: the plate within the band width of its outline on every side (the long sides, both ends and the rounded corners), through the full plate thickness, with the detent notches | `lidRim` | slate blue-grey `#587A9E`, as the bin body |
| Lid center | The flat plate inside the edge band, through the plate thickness | `lidCenter` | light grey `#C8CDD6` |

The bin's parts are the bin, and the lid's parts are the lid: each pair is an exact partition of
the uncolored piece, with no overlap and no gap (`ColoredPartsTests` checks the volumes, the
intersection and the symmetric difference). The dividers are the bin inside the strips between
the pockets (in plan view, the rectangle the pockets tile minus the pockets), within the interior
footprint from the pocket floor up, minus the wall. So the color changes at the pocket floor, a
divider that stands on the ridge between two feet takes the ridge's top with it, and a ridge that
crosses the middle of a compartment stays the body color. In the Flush raised style the whole flat
floor is the body color and the dividers start on it. A bin with no dividers (Compartments X and Y both 1) has only the Bin body part. `.binSlice` is one Bin body part.

The lid center is the plate's plan outline inset by the band width, extruded over the plate
thickness, minus the detent notches; the Lid rim and lip part is the rest of the lid. So the lid
shows the rim color all round its edge from above, from the sides and from below, and the center
color only inside the band. The band width is the width of the tongue's foot on the long sides,
from the plate edge to the tongue's inner face, so the band lies under the tongue there: the lip's
inner face in the wall profile (`dWall2 - dClear`, 2.596 mm in from the outer wall face) less the
slot face (1.2 mm) and the Lid clearance. That is 1.2 mm at the default clearance of 0.20 (1.3 at
0.10, 0.8 at the 0.6 maximum): the band follows Lid clearance, while the center itself stays the
same size. The smallest lid (1 by 1) still has a 36.3 mm center, so the Lid center part is never
empty.

Each part is a separate object in the exported 3MF, named as above, with its color as a 3MF
material color group (`m:colorgroup`). The parts keep their positions, so they sit together as
the assembled piece. No extruder or filament numbers are set: the colors are display and material
colors, and how a slicer maps them to filaments (or whether it shows them at all) is for you to
confirm in your slicer. Printing on a single-color printer works the same way, except that each
piece is two objects (four for the assemblies); keep them where the file places them so they
print as one piece. Whether a slicer offers to merge them into one object is not verified here.

## Build

```
swift run lidded-bin
```

This writes five 3MF files to `Models/`, all built with the default parameter values:
`Bin`, `Lid` (in print orientation, on the plate), `Bin and lid (closed)` (the lid seated in the
slot), `Bin and lid (separated)` (both pieces beside each other, each in print orientation on the
plate at z = 0, so a slicer can import the file with the pieces already laid out) and
`Bin and lid (open)` (the lid slid out). Each model is made of the colored parts of
"Colors": the Bin of "Bin body" and "Dividers", the Lid of "Lid rim and lip" and "Lid center",
and the assemblies of all four. `Models/` is generated output and is git-ignored. The bin slice is not
exported; it remains available as `LiddedBinPart.binSlice` in the library.

Slicers keep the relative positions of the objects in a 3MF but may re-center the group on the
bed. Printing the separated model needs a bed at least as large as both pieces plus the 10 mm
gap: for the default 2x2x3 bin that is about 175 x 84 mm.

## Customizer parameters

`Sources/lidded-bin/main.swift` declares the parameters of the web customizer with Cadova's
`@Parameter`, one tab per model. Every default comes from `LiddedBinInput.defaults` (the
defaults of `LiddedBinConfiguration`), and every range from `LiddedBinLimits`. The model library
itself does not use `@Parameter`.

| Label | Values | Default | lid-bin.scad | Tabs |
|---|---|---|---|---|
| Grid width | 1...6 cells | 2 | `gridx` | all |
| Grid depth | 1...6 cells | 2 | `gridy` | all |
| Height style | 7 mm units, Internal height, Overall height | 7 mm units | `gridz_define` | all |
| Height | 1...12 units, step 1 | 3 | `gridz` | all, when Height style is 7 mm units |
| Internal height | 5...76.8 mm, step 1 | 20 | `gridz` | all, when Height style is Internal height |
| Overall height | 14...84 mm, step 1 | 30 | `gridz` | all, when Height style is Overall height |
| Snap to 7 mm | on, off | off | `enable_zsnap` | all, when Height style is Internal height or Overall height |
| Internal block height | 0...80 mm | 0 | `height_internal` | all |
| Lid direction | Up, Down, Left, Right | Left | `Lid_Orientation` | all |
| Lip grips | None, Along X, Along Y, Along X and Y | Along X and Y | `Lip_Grips` | all |
| Lid clearance | 0.10...0.6 mm, step 0.05 | 0.20 | gap between the lid and the slot on each side; smaller is tighter (original value 0.45) | all |
| Lid chamfer | 0.8...1.8 mm, step 0.1 | 1.4 | rise of the slot roof that holds the lid down; the lid's chamfer follows it, about 0.6 times as tall (original value 0.8) | all |
| Detent interference | 0.10...0.40 mm, step 0.05 | 0.25 | overlap of the bump with the lid's edge; more is a firmer click and a stiffer lid (original value 0.15) | all |
| Interior style | Minimal, Partially raised, Flush raised | Minimal | `Interior_Style` (Flush raised is not in lid-bin.scad) | Bin and the three assembly tabs |
| Compartment layout | Equal grid, Two sizes | Equal grid | `div_pattern` | Bin and the three assembly tabs |
| Compartments X | 1...12 compartments | 6 | `divx`: the number of compartments along X. 1 is a single open compartment, 2 adds one divider, N adds N - 1 | Bin and the three assembly tabs |
| Compartments Y | 1...12 compartments | 6 | `divy`: the number of compartments along Y, counted as Compartments X | Bin and the three assembly tabs |
| Size multiple | 1...5, step 0.5 | 2 | `div_multiple` | Bin and the three assembly tabs, when Compartment layout is Two sizes |
| Bin color | color picker | `#587A9E` | none (colors the Bin body part) | Bin and the three assembly tabs |
| Divider color | color picker | `#E8912D` | none (colors the Dividers part) | Bin and the three assembly tabs |
| Lid rim color | color picker | `#587A9E` | none (colors the Lid rim and lip part) | Lid and the three assembly tabs |
| Lid center color | color picker | `#C8CDD6` | none (colors the Lid center part) | Lid and the three assembly tabs |

All parameters are declared in the project, so a value is shared between the tabs that show it.
Cadova lists a parameter on a tab only when that model reads it, and on every tab when the
project body reads it. The settings the lid depends on, including the three lid fit controls
(which shape both parts), are read in the project body, so every tab lists the lid fit controls
right after Lip grips; the bin-only settings are read only inside the `Bin` and the
three assembly models, since the lid geometry does not depend on them. The four colors are
declared after Detent interference and read only by the models that have those parts, so each
tab lists them last: the Bin tab the bin and divider colors, the Lid tab the two lid colors, and
the assembly tabs all four. Their defaults come from `LiddedBinColors.defaults`. The conditional
parameters are read only while they apply.
Internal block height is clamped to the bin's storage height by `validated()`.

The catalog can be printed natively, the way Cadova's customizer page asks for it: write a
request file and run the built executable with `CADOVA_CUSTOMIZER_REQUEST` naming it.

```
swift build
echo '{"listParameters": "/tmp/catalog.json"}' > /tmp/request.json
CADOVA_CUSTOMIZER_REQUEST=/tmp/request.json .build/debug/lidded-bin
```

A `"values"` object in the request, keyed by the parameter keys the catalog lists, gives the
catalog for other choices (for example another Height style). This request format is Cadova's
internal contract with its customizer page (Cadova 1.3.0), not public API.
`CustomizerCatalogTests` checks the catalog this way, so run `swift build` before `swift test`
after changing `main.swift`; `swift test` does not rebuild the executable.

## Publishing the customizer

`swift package generate-customizer` builds a static web page from `lidded-bin`, with the model
compiled to WebAssembly so it runs in the visitor's browser. The page offers five tabs, one for
each exported model (`Bin`, `Lid`, `Bin and lid (closed)`, `Bin and lid (separated)` and
`Bin and lid (open)`), each with the parameters listed
above and a download button. The four color controls are color pickers (Cadova's `Color`
parameter type); how the page previews the part colors has not been checked in a browser.

Build it locally (needs the Swift 6.4.0 toolchain from swift.org, and network access to fetch
dependencies):

```
cd LiddedBin
swift package generate-customizer
```

This writes the page to `Customizer/`, which is git-ignored. The command was not run in the
development sandbox (no network and no WebAssembly toolchain), so neither the build nor the
page's behavior in a browser has been verified here.

Preview it locally:

```
python3 -m http.server --directory Customizer 8000
```

Then open <http://localhost:8000>.

To publish on GitHub Pages, push the repository to GitHub, open Settings, Pages, and set the
source to GitHub Actions. The workflow `.github/workflows/customizer.yml` at the repository root
builds `lidded-bin` from the `LiddedBin` folder with Cadova's `BuildCustomizer` action (pinned to
1.3.0, the Cadova version in `Package.resolved`) and deploys it on every push to `main` or on a
manual run. The sibling `../GridfinityRebuilt` dependency resolves because both packages are in
the same checkout.

The page shows the model's author and license (see "Attribution and license"), so it carries the
CC BY 4.0 attribution to smkent / bulbasaur0.

Limits of the WebAssembly build, from the Cadova guide: text can only use fonts included as
resources, ICU locale data is missing (so `DateFormatter` and `NumberFormatter` stop the build),
models build on a single thread and so are slower than native, and the browser gives a model
less stack space. `LiddedBin` does not use text.

## Verify against OpenSCAD

OpenSCAD is required (the scripts expect `/opt/homebrew/bin/openscad`).

```
python3 -I Reference/generate.py     # optionally pass case names to regenerate only those
swift test
```

`generate.py` runs `lid-bin.scad` for each case with `-D $fn=64` plus the case's overrides. It
writes `Reference/reference.json` (volume and bounding box, measured on OpenSCAD's
full-precision output) and `Reference/stl/<case>.stl`. `Reference/stl/` is generated and
git-ignored; `reference.json` is committed. The tests need the STL files, so run the script
first on a fresh checkout.

Each reference test builds the Cadova geometry for the same settings with `cornerSegments = 16`
(a quarter turn at `$fn = 64`) and compares it to OpenSCAD:

- volume: relative tolerance 1e-4
- bounding box: 0.05 mm per coordinate
- symmetric difference against the OpenSCAD mesh: 0.05 mm^3

Cases cover bins, lids, all four lid orientations, grips, height modes, the multisize pattern,
fit-constant sweeps, and the bin slice.

Float32 note: the STL files in `Reference/stl/` have every coordinate rounded to float32, as a
binary STL would store. OpenSCAD's double-precision output mixes rounded and exact vertices on
shared planes, and Cadova's import then loses small wedges of volume (up to about 6 mm^3 in
the cases investigated). Rounding fixes that, and it adds a noise floor of roughly 0.001 to
0.02 mm^3 to the symmetric difference, which is why the tolerance is 0.05. The one exception
is `lid_2x2x3_fit_sweep`, which `generate.py` keeps in full precision (`FULL_PRECISION`)
because float32 rounding made the import drop a wedge there.

The suite currently has 117 tests (`swift build --skip-update && swift test --skip-update`), all passing. `ProductionTests`
build the default configuration with `cornerSegments == nil` and Cadova's default segmentation,
as the exporter does, and check volume, bounds, symmetric difference and the closed bin/lid
interference against the references (with the original lid fit preset); `LidFitTests` measure
the lid clearance, the slot roof and the tongue chamfer by ray casts on the closed assembly;
`DetentTests` measure the detent (the bump's overlap with the plate edge, its plan-view angles,
the closed seat in all four lid directions, and a slide sweep of the overlap) by ray casts and
intersection volumes. `ColoredPartsTests` checks the color split: the exact partitions (for the
default bin, the production segmentation, a 3x2x3 bin with the lid up, the original preset and a
multisize bin, and for the lid also a clearance of 0.10 and a 1x1 bin), that the dividers start
at the pocket floor and stay clear of the wall, the lid's edge band (its width against the measured
tongue foot for three clearances, the center's bounds, ray casts across every side and a corner,
and the band volumes), the single-compartment bin without a Dividers part, the part names and colors of every
colored model, their placement against the uncolored models, and the names and colors in the
exported 3MF of the separated and the closed assemblies; the partition, single-piece and pocket
floor checks also run on three Flush raised bins. `FlushRaisedTests` checks the Flush raised style,
which has no OpenSCAD reference: rays cast down over every compartment (1 mm clear of the
dividers, the wall and the interior's rounded corners) of a 2x2x3 bin with 2 by 1 and with 6 by 6
compartments, a 1x1x3 bin and a 3x2x3 two-size bin all meet the floor at 6.1 mm within 0.001 mm,
while the same rays on Minimal and Partially raised bins find recesses; the flush bin contains the
Minimal bin, is the same above the floor (the wall and lip outside the interior have the same
volume), has the same bounds and the same lid; the pockets run from the flush floor to the pocket
top; and the short-bin rule (the 1 unit bin is built as Partially raised, every other height has
at least 2 mm of depth).
`ValidationTests` also checks that `divMultiple` of 0 or less is clamped. The closed bin and
lid assemblies have no OpenSCAD CLI reference (`lid-bin.scad` uses them for preview only), so
the lid placement there is checked by footprint, shift and overlap tests instead.

## Known differences

- The Flush raised interior style is an addition: lid-bin.scad offers only `minimal` and
  `partial_raised`.
- Custom compartment pockets are dropped: the `custom` value of `div_pattern` and its text
  notice are not ported, because `Text` cannot use system fonts in the planned web customizer.
- The bin slice (`binSlice`) is a hollow ring: the port cuts the whole interior when there are no
  pockets. The original OpenSCAD model produces a solid block there because the interior cut
  intersects with an empty `children()` and cuts nothing.
- The customizer offers 1 to 12 compartments per axis; the original model's `divx` and `divy` of 0
  (a solid block) is not offered. Direct use of the model API with a count of 0 gives the hollow cut
  that `binSlice` uses. The references for it (`bin_1x1x2_nogrips_div0`, `bin_slice_2x2x3`,
  `bin_slice_1x1x2_up`) come from a patched copy of
  `lid-bin.scad` that `generate.py` writes to `Reference/generated/` (git-ignored); the original
  file is not edited.
- In the closed position the lid and the bin overlap by about 1.4 mm^3 (1.34 mm^3 with the
  default lid fit): a 0.1 mm wide sliver at the open end, where the lid's rim meets the bin wall
  that `gf_bin_lid_lip_mask`, moved by `lid_lip_fit_tolerance`, leaves standing. This is present
  in the original design, not introduced by the port. The two parts are
  exported as separate bodies, so the assembly volume is the sum of both.
