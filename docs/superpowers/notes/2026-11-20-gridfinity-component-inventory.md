# gridfinity-rebuilt-openscad: component inventory for Cadova customizers

Date: 2026-11-20. Scope: the four top-level files of the OpenSCAD copy at
`Lidded Bins/gridfinity-rebuilt-openscad/` (bins, baseplate, lite, spiral vase), the utility file and
`standard.scad`, measured against what `GridfinityRebuilt` (Swift) already ports and how `LiddedBin`
turns it into a customizer.

Conventions in this note:

- "Verified" facts come from reading the code. Anything marked **(inferred)** was reasoned out and not
  run; check it against OpenSCAD before relying on it.
- Line numbers refer to the OpenSCAD files as they are in this copy (utility file: 531 lines).
- Status: **PORTED** (Swift symbol named), **PARTIAL** (exists but lacks an option the component
  needs), **MISSING**.
- Installed OpenSCAD: `/opt/homebrew/bin/openscad`, version 2026.10.11.

## 0. Shared utility module status (gridfinity-rebuilt-utility.scad)

| OpenSCAD (line) | What it does | Swift status |
|---|---|---|
| `hf`, `height(z,d,l,s)` (9-10) | gridz to `$dh` in mm for the three `gridz_define` modes, lip handling, 7 mm snap, minus `h_base` | PORTED `Dimensions.binHeight(_:mode:lip:snap:)`, `rawHeight`, `HeightMode`, `LipStyle` |
| `cutEqual` (19-23) | `n_divx` by `n_divy` equal `cut()` compartments | MISSING |
| `cutCylinders` (34-56) | top recess of depth `coutout_depth` plus a grid of cylinders along X, Y or Z | MISSING (needs only ported pieces plus `Cylinder`) |
| `gridfinityInit` (61-79) | sets `$gxx $gyy $dh $dh0 $style_lip`, block_bottom minus children, plus wall (lip profile if `sl==0`, else lipless) | PORTED `BinGeometry.shell(cutting:cornerSegments:)` |
| `cut` (92-96) | one compartment via `block_cutter`, clamped with `clp`, z shifted by `-$dh-h_base` | MISSING |
| `cut_move` (100-104) | moves children to compartment center at z = `($dh0==0?$dh:$dh0)+h_base` | PORTED `BinGeometry.placed(x:y:w:h:_:)` |
| `profile_base` (108-117) | 2D base chamfer profile | PORTED `Dimensions.baseProfile()` |
| `gridfinityBase` (119-149) | grid of `block_base`, auto sub-division (`dbnx`), `final_cut` slab and clip, `only_corners` holes, offset `off` | MISSING |
| `block_base` (151-165) | `block_base_solid` minus 4 holes (style 1-3 `block_base_hole`, style 4 `refined_hole`), `render(convexity=2)` | PARTIAL: solid only |
| `block_base_solid` (167-185) | one base foot, two hulls of rounded rects, offset `o` | PORTED `Dimensions.blockBaseSolid(nx:ny:length:offset:)` |
| `block_base_hole(style_hole,o)` (187-202) | magnet cylinder (r_hole2, depth h_hole), style 3 printable slit (two cubes leave a bridge), style >1 screw cylinder (r_hole1, 2*h_base tall centered); `o` shrinks/grows radii and depth | MISSING |
| `refined_hole` (205-235) | Gridfinity Refined side-loading magnet slot (hull of cylinder r=2.93 h=1.9 and a cube at x=10) plus a poke-through hull (d=2.5), raised by `2*h_slit` | MISSING |
| `profile_wall_sub_sub`, `profile_wall_sub`, `profile_wall` (237-275) | wall cross-section with stacking lip and top fillet | PORTED `Dimensions.wallProfile(height:)` (inner wall is fixed at `dWall/2`, PARTIAL for the vase, see 4.3) |
| `profile_wall2` (278-282) | lipless wall, `d_wall` by `$dh` | PORTED `Dimensions.lipelessWallProfile(height:)` |
| `block_wall` (284-288) | sweep of profile around the bin outline | PORTED `Dimensions.blockWall(gridX:gridY:length:profile:cornerSegments:)` |
| `block_bottom` (290-293) | solid floor block from `h_base+0.1` | PORTED `Dimensions.blockBottom(height:gridX:gridY:length:)` |
| `cut_move_unsafe` (295-302) | unclamped compartment placement | PORTED inside `placed` (not public) |
| `block_cutter(x,y,w,h,t,s)` (304-411) | the compartment cutter: main body, partial tabs, lip relief cuts, scoop; up to four `fillet_cutter` minkowskis | MISSING |
| `transform_main` (413-417) | linear_extrude a profile `xlen-2*r_f2` long, centered | MISSING |
| `transform_tab(type,xlen,cut)` (419-426) | extrudes the non-tab part beside a partial tab; left/center/right via mirror and copy_mirror | MISSING |
| `fillet_cutter(t)` (428-434) | `minkowski` with `sphere(r_f2 - t/1000)` | MISSING (no Minkowski in Cadova, see section 4 notes) |
| `profile_cutter(h,l,s)` (436-466) | 2D hull: compartment cross-section with the scoop quarter circle (radius `max(s*$dh/2-r_f2,0)`) | MISSING |
| `profile_cutter_tab(h,tab,ang)` (468-474) | 2D triangle under the tab, `offset(delta=r_f2)` | MISSING |
| `clp` (478) | clamp | PARTIAL: private inside `placed` |
| `rounded_rectangle` (480-485) | `linear_extrude(offset(r) offset(-r) square)` | PORTED `roundedRectangle`, `roundedRectangle2D` |
| `rounded_square` (487-489) | square version | MISSING (one line) |
| `copy_mirror(vec)` (491-496) | child plus mirrored child | MISSING (one line) |
| `pattern_linear(x,y,sx,sy)` (498-505) | grid of copies, `ceil(x)` copies but centered with the raw `x` | PARTIAL `patternLinear(x:y:spacingX:spacingY:_:)`: `Int` counts only, so fractional counts (half bins, see quirks Q7) are not reproducible |
| `pattern_circular(n)` (507-511) | n copies rotated by `i*360/n`, i = 1..n | MISSING (one line) |
| `sweep_rounded(w,h)` (513-531) | four straight extrusions and four 90 degree `rotate_extrude` corners | PORTED `sweepRounded(width:height:profile:cornerSegments:)` |

Constants from `standard.scad` already in `Dimensions`: `h_base r_base r_c1 r_c2 h_bot r_fo1 r_fo2 r_fo3 l_grid d_div d_wall d_clear h_lip r_f1 r_f2`, derived `d_wall2 d_magic`.
Not yet in Swift: holes `r_hole1=1.5 r_hole2=3.25 d_hole=26 d_hole_from_side=8 h_hole=2.4 h_slit=0.2`; tabs
`d_tabh=15.85 d_tabw=42 a_tab=36`; baseplate `bp_h_bot=6.4 bp_cut_size=21.4 bp_cut_depth=4 bp_rcut_width=8.5 bp_rcut_length=4.25 bp_rcut_depth=2 bp_xy_clearance=0.5 d_cs=2.5 r_skel=2 r_cb=2.75 h_cb=3 h_skel=1`.

---

## 1. Bins: `gridfinity-rebuilt-bins.scad` (177 lines)

### 1.1 What it makes

The standard Gridfinity bin: a stackable bin (`gridx` by `gridy` cells, height in 7 mm units or mm) with
a base of feet that seat in a baseplate, optional magnet/screw holes in each foot, and an interior
that is either solid, an equal grid of compartments with label tabs and a front finger scoop, or a
grid of cylindrical holes. Entry (lines 87-100, top level, no wrapper module):

```
gridfinityInit(gridx, gridy, height(gridz, gridz_define, style_lip, enable_zsnap), height_internal) {
    if (divx > 0 && divy > 0) cutEqual(divx, divy, style_tab, scoop);
    else if (cdivx > 0 && cdivy > 0) cutCylinders(cdivx, cdivy, cd, ch, c_depth, c_orientation);
}
gridfinityBase(gridx, gridy, l_grid, div_base_x, div_base_y, style_hole, only_corners=only_corners);
```

The defaults (`divx = divy = 0`) give a **solid** 3x2x6 block with refined holes. Lines 103-177 are
commented examples of `cut()` layouts (custom positions, overlapping compartments, `cut_move` with
child shapes, loops); they need source editing and are not customizer parameters.

### 1.2 Parameters (exactly as declared; no explicit ranges unless shown)

| Section | Name | Default | Choices / range | Comment text |
|---|---|---|---|---|
| Setup Parameters | `$fa` | 8 | | (none) |
| | `$fs` | 0.25 | | (none) |
| General Settings | `gridx` | 3 | | number of bases along x-axis |
| | `gridy` | 2 | | number of bases along y-axis |
| | `gridz` | 6 | | bin height. See bin height information and "gridz_define" below. |
| Linear Compartments | `divx` | 0 | | number of X Divisions (set to zero to have solid bin) |
| | `divy` | 0 | | number of Y Divisions (set to zero to have solid bin) |
| Cylindrical Compartments | `cdivx` | 0 | | number of cylindrical X Divisions (mutually exclusive to Linear Compartments) |
| | `cdivy` | 0 | | number of cylindrical Y Divisions (mutually exclusive to Linear Compartments) |
| | `c_orientation` | 2 | `[0: x direction, 1: y direction, 2: z direction]` | orientation |
| | `cd` | 10 | | diameter of cylindrical cut outs |
| | `ch` | 1 | | cylinder height |
| | `c_depth` | 1 | | spacing to lid |
| Height | `gridz_define` | 0 | `[0:gridz is the height of bins in units of 7mm increments - Zack's method,1:gridz is the internal height in millimeters, 2:gridz is the overall external height of the bin in millimeters]` | determine what the variable "gridz" applies to based on your use case |
| | `height_internal` | 0 | | overrides internal block height of bin (for solid containers). Leave zero for default height. Units: mm |
| | `enable_zsnap` | false | | snap gridz height to nearest 7mm increment |
| Features | `style_tab` | 1 | `[0:Full,1:Auto,2:Left,3:Center,4:Right,5:None]` | the type of tabs |
| | `style_lip` | 0 | `[0: Regular lip, 1:remove lip subtractively, 2: remove lip and retain height]` | how should the top lip act |
| | `scoop` | 1 | `[0:0.1:1]` | scoop weight percentage. 0 disables scoop, 1 is regular scoop. Any real number will scale the scoop. |
| | `only_corners` | false | | only cut magnet/screw holes at the corners of the bin to save uneccesary print time |
| Base | `style_hole` | 4 | `[0:no holes, 1:magnet holes only, 2: magnet and screw holes - no printable slit, 3: magnet and screw holes - printable slit, 4: Gridfinity Refined hole - no glue needed]` | (none) |
| | `div_base_x` | 0 | | number of divisions per 1 unit of base along the X axis. (default 1, only use integers. 0 means automatically guess the right division) |
| | `div_base_y` | 0 | | number of divisions per 1 unit of base along the Y axis. (default 1, only use integers. 0 means automatically guess the right division) |

Derived values:

- `$dh = height(gridz, gridz_define, style_lip, enable_zsnap)`; note `style_lip` is passed as the
  `l` argument of `height`, so lip style 1 subtracts `h_lip` in mode 2 and lip style 2 adds `h_lip` in
  all modes. Default: 6 units gives 42 - 5 = 37 mm.
- `$dh0 = height_internal`; bottom block height is `$dh - 0.1` when 0.
- Top of the bin: `$dh + h_base + h_lip` with lip (24.548 mm at `$dh = 16`, from `init_2x1x3` reference
  bounds), `$dh + h_base` lipless (21.0 at `$dh = 16`).
- Interior mode: linear if both `divx, divy > 0`, else cylinders if both `cdivx, cdivy > 0`, else solid.
- In `block_cutter`: `zsmall = ($dh+h_base)/7 < 3` turns tabs off (bins under 3 units);
  partial (non-full) tab only if `xlen - d_tabw > 4*r_f2`, i.e. compartment wider than about 53.2 mm;
  tab alignment `style = t in 2...4 ? t-3 : (x==0 ? -1 : xcutlast ? 1 : 0)`.
- In `gridfinityBase`: `dbnx = 1/(dx==0 ? first i in 1...5 with gx*i integer (else 1) : round(dx))`.

### 1.3 Geometry modules used

| Module | Role here | Status |
|---|---|---|
| `height` | `$dh` | PORTED `binHeight` |
| `gridfinityInit` | shell | PORTED `BinGeometry.shell` |
| `block_bottom`, `block_wall`, `sweep_rounded`, `profile_wall`, `profile_wall2`, `profile_base` | shell parts | PORTED |
| `cutEqual` then `cut` then `block_cutter` | compartments | MISSING |
| `block_cutter` internals: `transform_main`, `transform_tab`, `fillet_cutter`, `profile_cutter`, `profile_cutter_tab`, `copy_mirror`, `clp` | see table 0 | MISSING |
| Tab styles in `block_cutter` | 0 Full: no partial-tab blocks, the main cutter subtracts the tab triangle over the whole width. 1 Auto: partial tab, left for compartments at x=0, right for the last column, center elsewhere. 2/3/4 Left/Center/Right: partial tab forced. 5 None: no tab (only the 45 degree lip relief at the back row). Tabs also vanish when `zsmall`. Tab profile: triangle `[[0,h],[d_tabh,h],[0,h-d_tabh*tan(36)]]` grown by `offset(delta=r_f2)`; lip relief triangle `v_len_lip = d_wall2-d_wall+1.2` at 45 degrees | MISSING |
| Scoop | quarter circle of radius `max(s*$dh/2 - r_f2, 0)` at the front (y=0 row) in `profile_cutter`; `extent` pulls the first-row cutter back by `d_wall2-d_wall-d_clear` under the lip | MISSING |
| Fillets | each cutter piece is `minkowski` with a sphere of `r_f2 = 2.8` minus `t/1000` (t=0..3 so the pieces are not coplanar) | MISSING |
| `cutCylinders` | rounded recess `gridx*42-2*d_wall` by `gridy*42-2*d_wall`, depth `c_depth`, plus `pattern_linear` cylinders r=`cd/2`, length `2*ch` centered at `-c_depth`, spacing `(grid_mm-2)/n`; orientation 0 rotates `[0,90,0]`, 1 `[90,0,0]`, 2 none | MISSING (uses `placed`, `roundedRectangle`, `patternLinear`) |
| `gridfinityBase` | feet, `final_cut` slab at `h_base` (height `h_bot/1.5`) and clip to `gx*l-0.5` outline, `only_corners` | MISSING |
| `block_base` and `block_base_solid` | one foot with holes | solid PORTED, holes MISSING |
| `block_base_hole` styles 1, 2, 3 and `refined_hole` (style 4) | 1: magnet r 3.25 depth 2.4. 2: plus screw r 1.5 through. 3: magnet depth 2.6 with a slit bridge (cubes cut at `h_hole`, leaving a 2*(r1+0.1) slot) plus screw. 4: refined side-loading slot 0.4 mm above the bottom, plus poke hole | MISSING |
| `pattern_linear`, `pattern_circular` | feet grid, holes | PARTIAL / MISSING |
| `cut_move` | cylinders placement | PORTED `placed` |

### 1.4 Hard geometry techniques

| Technique | Where | Cadova feature to check | Confidence |
|---|---|---|---|
| 3D `minkowski` with sphere | `fillet_cutter`, every compartment, 2 to 4 per compartment | No Minkowski API found in Cadova sources (grep). Options: (a) `offset(amount: r, style: .round)` on 3D (Offset3D, "slower than most operations", exact distance-based, follows segmentation); (b) exact parity: Minkowski distributes over union, and for a convex piece P with a convex polyhedral sphere S it is `convexHull` of all pairwise vertex sums, so build each cutter as a union of convex pieces and hull `{p + s}` with a `Mesh` or point list that reproduces OpenSCAD's sphere vertices (`(fn+1)/2` rings at phi = 180*(i+0.5)/rings). `convexHull(adding:)` exists | (a) medium for production (speed in WASM unknown), (b) medium-high for reference parity |
| 2D `hull` | `profile_cutter` | `convexHull()` on 2D | high |
| `offset(delta)` | `profile_cutter_tab` | `offset(amount:style: .miter)`; default `miterLimit` is 5, the sharpest corner is 36 degrees (miter ratio 1/sin(18) = 3.24), so the default suffices for angles above about 23 degrees | high |
| `linear_extrude` (plain) | `transform_main`, `transform_tab` | `extruded(height:)` | high |
| `hull` of 3D | `refined_hole` | `convexHull()` 3D | high |
| `render(convexity=2)` | `block_base` | no-op in Cadova (OpenSCAD caching only) | n/a |
| `$fa=8 $fs=0.25` | file top | `.withSegmentation(minAngle: 8°, minSize: 0.25)`. Cadova truncates (`Int(...)`) where OpenSCAD takes `ceil`; with $fa=8 the angular cap (45) wins for r above about 1.43 mm, so counts mostly agree **(inferred)** | high |

No `rotate_extrude` beyond `sweep_rounded` (ported), no text, no `linear_extrude` scale/twist, no polyhedron.

### 1.5 Overlap with the lidded bin

Shared and already ported: `binHeight`, `BinGeometry` shell and `placed`, wall profile, `blockWall`,
`blockBottom`, `blockBaseSolid`, `patternLinear`, `roundedRectangle2D` (LiddedBin uses each of these;
counted by grep in `LiddedBin/Sources`). Not shared: the lidded bin builds its own pockets
(rectangular `pocketInterior`) and its own base grid (`baseGrid` with a clip box inside each cell) and
has no holes, tabs, scoops or fillet cutters. The height-style UI (`HeightStyle` with three height
controls, snap) and the `Input` to `Configuration` pattern (`LiddedBinInput.configuration`, then
`validated()`) can be copied directly.

### 1.6 Size and risk

**Large.** About 350 to 500 Swift lines for `block_cutter` and helpers, 150 for holes and
`gridfinityBase`. Risks:

- `block_cutter` is dense: about 20 conditionals (`xcutfirst/xcutlast/ycutfirst/ycutlast`, `zsmall`,
  `t`, `s`) select pieces. Every branch needs a reference case.
- Minkowski fidelity (symmetric difference against a sphere-tessellated OpenSCAD fillet) and cost:
  a 6x6 compartment bin has 36 to 144 minkowski operations.
- Tab profile miter and the `t/1000` radius nudges must be reproduced or the pieces become coplanar.
- Half-cell bins (`gridx = 1.5`) depend on fractional `pattern_linear` (quirk Q7).

### 1.7 Behavior and web-page suggestions

What a user sees in OpenSCAD: F5 preview colors the bottom block firebrick, walls royalblue and
cutters (with `#`/debug off) are not visible; F6 render is one tomato-colored solid. The bin sits with
its feet at z = 0, upright, ready to print. Rendering with fillets is slow in CGAL and fast with
Manifold (the info block recommends fast-csg).

Suggestions (only suggestions):

- Merge `divx/divy/cdivx/cdivy` behind one "Interior" choice: Solid, Compartments, Cylinders. Show
  compartment counts 1...N (1 = one open compartment), cylinder counts, orientation, diameter, depth
  only for their choice. This removes the silent "both must be above zero" rule.
- Reuse the lidded bin's height style controls and limits.
- Tab style: menu of 6; hide when height is under 3 units (tabs are dropped anyway) or show a note.
- Scoop: slider 0...1, step 0.1; only for Compartments.
- Base hole style: menu of 5; "Only corners" only when holes are on.
- `div_base_x/y`: hide, or an advanced "Base subdivision" (Auto, 1, 2, 3, 4).
- `height_internal`: only for the Solid interior (its own comment says "for solid containers"; see Q3).
- Replace `$fa/$fs` by a quality choice, or fix the segmentation.
- Allow half-cell grid sizes (step 0.5) only once fractional `patternLinear` is ported.

---

## 2. Baseplate: `gridfinity-rebuilt-baseplate.scad` (209 lines)

### 2.1 What it makes

A baseplate the bins sit in: a plate with one socket per cell (the bin foot shape at 0.5 mm clearance),
in five styles: thin (frame only), weighted (6.4 mm floor with a weight pocket per cell), skeletonized
(thin floor with cutouts around the hole bosses), screw together (skeleton plus horizontal screw holes
through the edges to join plates) and screw together minimal (cells cut through). Optional magnet holes
and countersunk or counterbored screw holes in the floor. Fit to drawer: a minimum size that pads the
plate beyond the grid, with alignment of the padding. Entry (line 63):
`gridfinityBaseplate(gridx, gridy, l_grid, distancex, distancey, style_plate, enable_magnet, style_hole, fitx, fity);`
defined in the same file (68-119).

### 2.2 Parameters

| Section | Name | Default | Choices / range | Comment text |
|---|---|---|---|---|
| Setup Parameters | `$fa` | 8 | | (none) |
| | `$fs` | 0.25 | | (none) |
| General Settings | `gridx` | 5 | | number of bases along x-axis |
| | `gridy` | 5 | | number of bases along y-axis |
| Screw Together Settings - Defaults work for M3 and 4-40 | `d_screw` | 3.35 | | screw diameter |
| | `d_screw_head` | 5 | | screw head diameter |
| | `screw_spacing` | .5 | | screw spacing distance |
| | `n_screws` | 1 | `[1:3]` | number of screws per grid block |
| Fit to Drawer | `distancex` | 0 | | minimum length of baseplate along x (leave zero to ignore, will automatically fill area if gridx is zero) |
| | `distancey` | 0 | | minimum length of baseplate along y (leave zero to ignore, will automatically fill area if gridy is zero) |
| | `fitx` | 0 | `[-1:0.1:1]` | where to align extra space along x |
| | `fity` | 0 | `[-1:0.1:1]` | where to align extra space along y |
| Styles | `style_plate` | 0 | `[0: thin, 1:weighted, 2:skeletonized, 3: screw together, 4: screw together minimal]` | baseplate styles |
| | `enable_magnet` | true | | enable magnet hole |
| | `style_hole` | 2 | `[0:none, 1:countersink, 2:counterbore]` | hole styles |

Derived (lines 60, 73-81, 121-134):

- `screw_together = style_plate == 3 || style_plate == 4` (global).
- `gx = gridx == 0 ? floor(distancex/42) : gridx`, same for y; `assert(gridx > 0 || dix > 0)`.
- `dx = max(gx*42 - bp_xy_clearance, distancex)`.
- `off` (floor depth below z = 0): screw together 6.75; thin 0; weighted `bp_h_bot` 6.4; skeletonized
  `h_skel + (magnet ? h_hole : 0) + (sh==0 ? d_screw : sh==1 ? d_cs : h_cb)`, i.e. 1 + 2.4 + 3 = 6.4 by default.
- `offsetx = distancex < dx ? 0 : (gx*42 - 0.5 - distancex)/2 * -fitx` (moves the outline, not the grid).

### 2.3 Geometry modules

| Module | Role | Status |
|---|---|---|
| `rounded_rectangle` (mirrored) | plate body, top at `h_base`, down to `-off`, radius `r_base` | PORTED |
| `gridfinityBase(gx, gy, 42, 1, 1, 0, 0.5, false)` | sockets: feet grown by 0.5, no holes, no final cut | MISSING (only `blockBaseSolid(offset:)` ported; needs the grid wrapper without holes) |
| top trim `rounded_rectangle(dx*2, dy*2, h_base*2)` at `h_base-0.6` | cuts the top 0.6 mm, so the plate top is z = 4.4 | trivial |
| `cutter_weight` (136-149) | weighted: 21.4 mm square pocket 4 deep plus four slot-and-round pockets 2 deep (8.5 wide, centered 10 mm out), at the plate bottom | MISSING (simple) |
| `profile_skeleton` (179-193) | skeleton: 2D `minkowski(difference(square, 4 corner minkowski(square, circle(r_hole2+r_skel+2))), circle(r_skel))`, extruded through | MISSING |
| minimal (sp 4) | `rounded_square(42-2*r_c2-2*r_c1, ..., r_fo3)` through each cell | MISSING (trivial) |
| `hole_pattern` (150-156) | 4 holes per cell at 13 mm from center; `render();` then children | MISSING (`pattern_circular`) |
| `block_base_hole(1)` | magnet hole only (r 3.25, z -2.4 to 2.4) when `enable_magnet` | MISSING (shared with bins) |
| `cutter_countersink` (158-167) | screw clearance r 1.75 through, plus cone (hull of two cylinders, r 1.75 to 4.25 over 2.5 mm) | MISSING |
| `cutter_counterbore` (169-177) | screw r 1.75 through, counterbore r 2.75 depth 3.2 with a printable slit bridge | MISSING |
| `cutter_screw_together` (195-209) | horizontal `d_screw` holes 21 mm long, centered on the grid edges at z `-off/2`, one row per cell, `n_screws` per cell spaced `d_screw_head + screw_spacing` | MISSING |
| `pattern_linear(gx, gy, 42)` | per-cell cutters | PORTED (integers here) |
| `copy_mirror`, `pattern_circular` | | MISSING (one line each) |

### 2.4 Hard geometry techniques

| Technique | Where | Cadova | Confidence |
|---|---|---|---|
| 2D `minkowski` with circle | `profile_skeleton` (twice) | 2D `offset(amount: r, style: .round)` is the same set; segment placement must match OpenSCAD's circle (`$fn`) for symmetric difference parity, as `roundedRectangle2D` already does | high |
| 3D `hull` | countersink cone | `Cylinder(bottomRadius:topRadius:height:)` or `convexHull()` | high |
| `render(convexity=6)` | per-cell cutter | no-op | n/a |
| `linear_extrude(center=true)` | weight, skeleton | `extruded` plus translate | high |

### 2.5 Overlap with the lidded bin

Only `blockBaseSolid(offset:)`, `roundedRectangle`, `patternLinear`. The baseplate is the mating part
of every bin, including the lidded bin, so a shared `Dimensions` matters (a baseplate made with
`dWall = 1.6` is unaffected since it uses no wall constants).

### 2.6 Size and risk

**Medium-small.** About 200 to 250 Swift lines plus `gridfinityBase`. Risks: fit-to-drawer logic and
its quirks (Q11), the skeleton minkowski parity, the `off` table, z placement (the plate bottom is at
`z = -off`, so a weighted plate spans -6.4 to 4.4).

### 2.7 Behavior and web-page suggestions

OpenSCAD output: one tomato solid with its top at z = 4.4 and its bottom at `-off` (below z = 0 for
every style except thin) **(inferred from the code; the port should decide whether to drop it to z = 0
for download)**. Suggestions:

- Plate style: 5 choices (menu). Show magnet and screw-hole style only for styles with a floor
  (weighted, skeletonized, screw together); in thin they cut only into the socket void **(inferred)**.
- Screw together settings only for styles 3 and 4; `n_screws` 1...3.
- Fit to drawer: "Size by" (Grid cells, Drawer size); drawer width/depth in mm; alignment sliders
  -1...1 only when the drawer exceeds the grid. Report the resulting cell count in `Metadata`
  description (Cadova updates metadata per build).
- Rename `style_hole` to "Screw holes" in the page so it is not confused with the bin's hole style.

---

## 3. Lite: `gridfinity-rebuilt-lite.scad` (136 lines)

### 3.1 What it makes

A material-saving bin: the usual bin and base, with the inside of the base hollowed to a shell of
`d_wall` thickness above a floor of `bottom_layer` mm, so the compartments reach down into the feet;
bosses of `d_wall` remain around magnet holes. Scoop is always off. Entry (line 59):
`gridfinityLite(gridx, gridy, gridz, gridz_define, style_lip, enable_zsnap, l_grid, div_base_x, div_base_y, style_hole, only_corners) { cutEqual(divx, divy, style_tab, scoop_weight = 0); }`.

### 3.2 Parameters

| Section | Name | Default | Choices | Comment text |
|---|---|---|---|---|
| Setup Parameters | `$fa`, `$fs` | 8, 0.25 | | (none) |
| General Settings | `gridx` | 3 | | number of bases along x-axis |
| | `gridy` | 3 | | number of bases along y-axis |
| | `gridz` | 6 | | bin height. See bin height information and "gridz_define" below. |
| Compartments | `divx` | 2 | | number of X Divisions |
| | `divy` | 2 | | number of y Divisions |
| Toggles | `enable_zsnap` | false | | snap gridz height to nearest 7mm increment |
| | `style_lip` | 0 | `[0: Regular lip, 1:remove lip subtractively, 2: remove lip and retain height]` | how should the top lip act |
| Other | `gridz_define` | 0 | same three as bins | determine what the variable "gridz" applies to based on your use case |
| | `style_tab` | 1 | `[0:Full,1:Auto,2:Left,3:Center,4:Right,5:None]` | the type of tabs |
| Base | `style_hole` | 0 | `[0:no holes, 1:magnet holes only, 2: magnet and screw holes - no printable slit, 3: magnet and screw holes - printable slit]` (no 4) | (none) |
| | `only_corners` | false | | only cut magnet/screw holes at the corners of the bin to save uneccesary print time |
| | `div_base_x`, `div_base_y` | 0 | | same text as bins |
| | `bottom_layer` | 1 | | thickness of bottom layer |

Derived: same `$dh` as bins. `bottom_layer` and `gridz` are read as globals inside `gridfinityLite`.

### 3.3 Construction (lines 65-136, verified reading)

`union { A, B }` where

- core = `intersection( gridfinityBase(..., off = -2*d_wall, final_cut = false) minus z above 2*h_base,
  interior footprint rounded rect (gx*42 - 0.5005 - 2*d_wall, radius r_f2), everything above z = bottom_layer )`.
  `off < 0` grows `block_base_hole` radii by `d_wall` (r2 = 3.25 + 0.95), so the core has larger holes and
  subtracting it leaves bosses.
- tall = `gridfinityInit(gx, gy, height(20, 0), 0, 42) children` moved down `4*h_base`: a 135 mm bin whose
  solid parts are the dividers, so `core - tall` keeps the core only under compartments.
- A = `(gridfinityInit(... children) + gridfinityBase(...)) - ((core + slab from h_base+d_clear, h_base tall) - tall)`.
- B = `(gridfinityInit(... children) - (core - tall))` moved down 1.6 mm, clipped to z 5...9 (`rounded_rectangle(gx*1000, gy*1000, gz*1000, gridz)` at z = 9 removed, z < 5 removed): extends the dividers' lower part into the hollow.

| Module | Status |
|---|---|
| `gridfinityInit` (three times), `height` | PORTED |
| `cutEqual`, `cut`, `block_cutter` (evaluated three times, with `$dh` of the bin and 135 mm) | MISSING |
| `gridfinityBase` with `off` < 0 and `final_cut = false` | MISSING |
| `block_base_hole` with `o` | MISSING |
| `rounded_rectangle` | PORTED |

### 3.4 Hard techniques

Nothing new beyond the bin: booleans of large solids, `minkowski` via the cutters (now three times).
Cost is the concern: three full cutter sets per build **(inferred: at least 3x a bin's cutter time)**.
Caching the cutter geometry once per `$dh` helps (Cadova caches by geometry identity; check).

### 3.5 Overlap with the lidded bin

Conceptually close to the lidded bin's "Minimal" interior style (hollow feet open into compartments),
but built differently: lite hollows by offsetting the full base by `-2*d_wall`; LiddedBin uses
`baseGridInterior()` (offset `-dWall - interiorBaseWallAdjust`, raised by `dWall`). No shared code
beyond the core ported modules.

### 3.6 Size and risk

**Medium** once the bin is ported (about 100 to 150 lines). Risks: the magic constants (`-1.6`, `9`,
`5`, `0.5005`, `4*h_base`) and the three `$dh` contexts must be reproduced exactly; `style_hole = 4`
breaks the boss logic (Q9); performance in WASM.

### 3.7 Suggestions

Could be a "Construction: Standard / Lite" choice on the bin page instead of its own page, with
"Bottom thickness" shown only for Lite and hole styles limited to 0...3 for Lite. Scoop and cylinders
hidden for Lite. Default compartments 2x2 differ from the bin's 0; pick one default per page.

---

## 4. Spiral vase: `gridfinity-spiral-vase.scad` (554 lines)

### 4.1 What it makes and why it is different

Two parts meant for a slicer's spiral vase mode (single continuous perimeter, no infill, no top
layers): `type = 0` a bin, `type = 1` a single 1x1 base foot that is printed separately and glued or
pressed into the bin bottom. Entry (lines 69-71): `if (type != 0) gridfinityBaseVase(); else gridfinityVase();`.

What is built differently, and why:

- The model is a **solid**, not a shell. Wall thickness comes from the slicer (`nozzle` extrusion width,
  "walls will be twice this size"), so walls are sized `nozzle*2` and internal features are offsets of
  `nozzle`.
- Internal walls are made with **magic slices**: 0.001 mm wide cuts (lines 171-174, 368-372) so the
  single perimeter enters the solid and returns, printing a double wall. Dividers are stacks of
  alternating half-length layer slabs (`block_divider`, lines 299-312, one `cube` per layer of height
  `layer`) so the vase perimeter can trace them.
- The bin has no feet. Its bottom has X-shaped cutouts per cell (`block_x`, `profile_x`), chosen by
  `style_base`; the base has a matching X cross on top (`linear_extrude(d_bottom) profile_x(0.1)`).
- Tabs are solid wedges (`profile_tab`, `transform_vtab_base`) cut from the vase body; funnels are
  hand-made tetrahedra (`polyhedron` in `profile_tabscoop`). The scoop is a ramp polygon
  (`transform_scoop`). A "pinch" (`block_pinch`) cuts a groove into the lip for stiffness; an "inset"
  (`block_inset`) cuts a triangular notch in front for strength around the scoop.
- It overrides utility code: top-level `a_tab = 40` replaces 36 everywhere in this file, and it
  redefines `profile_wall_sub_sub` (lines 398-407) with `nozzle*2` in place of `d_wall/2`, so
  `profile_wall` from the utility file uses the vase version. It sets `$dh = d_height` in
  `gridfinityVase`.
- Its height formula is its own (lines 79-80): mode 2 subtracts 3.8 (not `h_lip` 3.548), there is no
  "retain height" lip style, and the result does not go through `height()`.
- Tabs sit near the -Y wall and the scoop at +Y, the reverse of the bins file (tabs at +Y, scoop at
  y = 0 row, -Y), verified from `transform_vtab_base` (y = `d_tabh*cos(a_tab) - l*gy/2 + 0.25`) and
  `block_cutter`'s `rotate([90,0,-90])`.

### 4.2 Parameters

| Section | Name | Default | Choices | Comment text |
|---|---|---|---|---|
| Special Variables | `$fa`, `$fs` | 8, 0.25 | | (none) |
| Bin or Base | `type` | 0 | `[0:bin, 1:base]` | (none) |
| Printer Settings | `nozzle` | 0.6 | | extrusion width (walls will be twice this size) |
| | `layer` | 0.35 | | slicer layer size |
| | `bottom_layer` | 3 | | number of base layers on build plate |
| General Settings | `gridx` | 1 | | number of bases along x-axis |
| | `gridy` | 1 | | number of bases along y-axis |
| | `gridz` | 6 | | bin height. See bin height information and "gridz_define" below. |
| | `n_divx` | 2 | | number of compartments along x-axis |
| Toggles | `enable_holes` | true | | toggle holes on the base for magnet |
| | `enable_zsnap` | false | | round up the bin height to match the closest 7mm unit |
| | `enable_lip` | true | | toggle the lip on the top of the bin that allows stacking |
| | `enable_scoop_chamfer` | true | | chamfer inside bin for easy part removal |
| | `enable_funnel` | true | | funnel-like features on the back of tabs for fingers to grab |
| | `enable_inset` | true | | front inset (added for strength when there is a scoop) |
| | `enable_pinch` | true | | "pinches" the top lip of the bin, for added strength |
| Styles | `gridz_define` | 0 | same three as bins | determine what the variable "gridz" applies to based on your use case |
| | `style_tab` | 0 | `[0:continuous, 1:broken, 2:auto, 3:right, 4:center, 5:left, 6:none]` | how tabs are implemented |
| | `style_base` | 0 | `[0:all, 1:corners, 2:edges, 3:auto, 4:none]` | where to put X cutouts for attaching bases / selecting none will also disable crosses on bases |
| | `a_tab` | 40 | | tab angle |

Derived (lines 76-99), all globals:

| Name | Definition |
|---|---|
| `d_bottom` | `layer*max(bottom_layer,1)` |
| `x_l` | `l_grid/2` |
| `dht`, `d_height` | own height formula, snap, minus `h_base` |
| `f2c` | `sqrt(2)*(sqrt(2)-1)` |
| `me`, `m` | funnel size: `((gx*42-0.5)/n_divx) - nozzle*4 - r_fo1 - 12.7 - 4`; `m = min(d_tabw/1.8 + max(0,me), d_tabw/1.25)` |
| `d_ramp` | scoop ramp size from height |
| `d_edge` | free space beside a tab in a compartment |
| `n_st` | effective tab style: `gridz <= 3` gives 6 (none); `d_edge < 2` with a partial style gives 1 (broken); style 1 with `n_divx <= 1` gives 0; else `style_tab` |
| `n_x`, `spacing`, `shift`, `shiftauto` | tab copies and alignment |
| `xAll xCorner xEdge xAuto xNone`, `xFunc` | function literals selecting cells for `block_x` (needs OpenSCAD 2021+) |

### 4.3 Modules

| Module (lines) | Role | Status |
|---|---|---|
| `gridfinityVase` (102-154) | bin assembly | MISSING |
| `block_vase_base` (354-396) | `block_bottom(d_bottom)` plus `block_wall` with lip or lipless profile, magic slice, scoop piece, outside tab cutter | uses PORTED `blockBottom`, `blockWall`; profile PARTIAL (needs inner wall `nozzle*2`: make `wallProfile` take the inner wall half-thickness, default `dWall/2`) |
| `profile_wall_sub_sub` override (398-407) | vase wall section | PARTIAL (see above) |
| `block_vase(h)` (521-524) | inner solid used to clip features | MISSING (one `roundedRectangle`) |
| `transform_style`, `transform_vtab`, `transform_vtab_base`, `block_tab`, `block_tab_base`, `profile_tab` (439-509) | tabs: 2D triangle pair, `offset(delta)`, extruded along X, placed at the -Y side | MISSING |
| `block_tabscoop`, `profile_tabscoop` (466-483), `block_funnel_inside/outside`, `transform_funnel` (330-352) | funnels: `polyhedron` tetrahedron, `render()` | MISSING (`Mesh`) |
| `block_divider`, `block_divider_edgecut` (265-328) | dividers with per-layer alternating slabs | MISSING |
| `block_tabsupport` (253-263) | only reached when `n_divx < 1` (dead, Q13) | MISSING (probably drop) |
| `transform_scoop`, `block_flushscoop` (447-457, 511-519) | scoop ramp; `block_flushscoop` is never called | MISSING (`block_flushscoop` can be dropped) |
| `block_inset`, `block_inset_sub` (409-437) | front notch | MISSING |
| `block_pinch` (230-251) | lip groove swept with `sweep_rounded`, `offset(delta = -nozzle*sqrt(2))` of `profile_wall_sub` | MISSING; uses PORTED `sweepRounded`, needs `wallSub` made accessible |
| `block_x`, `block_x_sub`, `profile_x` (526-554) | X cutouts: square minus four `minkowski(square, circle)` corners, `offset(0.05)` (round) | MISSING |
| `gridfinityBaseVase` (156-201) | base: `block_base_blank` shell (offset `nozzle*4`), magic slice, four 45 degree ribs, magnet bosses and holes (`block_magnet_blank`, hull of two cylinders), X cross on top | MISSING |
| `block_base_blank` (216-228) | like `block_base_solid` but square, `d_bottom` tall foot, offset subtracts | MISSING (cannot reuse `blockBaseSolid` directly: different heights and offset sign) |
| `block_magnet_blank` (203-214) | cone boss via hull, optional half | MISSING |
| `pattern_linear`, `pattern_circular`, `copy_mirror`, `rounded_square`, `sweep_rounded` | | as table 0 |

### 4.4 Hard techniques

| Technique | Where | Cadova | Confidence |
|---|---|---|---|
| 0.001 mm slits | magic slices in bin and base | Manifold booleans should keep a 0.001 mm gap (the lidded bin's float32 note shows near-coincident vertices get merged on import, so the risk is in verification and export precision, not construction). Verify with `sliced(atZ:)` cross-sections, not volume | medium-low |
| `polyhedron` | `profile_tabscoop` | `Mesh(faces:name:cacheParameters:)` with `Vector3D` faces; check winding (OpenSCAD faces clockwise seen from outside) | high |
| 2D `minkowski` | `profile_x` | `offset(.round)` | high |
| `offset(r=0.05)` | `block_x_sub` | `offset(amount: 0.05, style: .round)` | high |
| `offset(delta)` negative and positive | `block_pinch`, `block_tab_base`, `block_divider_edgecut` | `.miter` | high |
| 3D `hull` | base blank, magnet blank | `convexHull()` | high |
| `render()` | `transform_funnel` | no-op | n/a |
| many small cubes | divider slices: about `(d_height - d_bottom)/layer` (about 100 for 6 units) slabs per divider | plain booleans; cost grows with height times dividers **(inferred)** | high |

### 4.5 Overlap with the lidded bin

`blockBottom`, `blockWall`, `sweepRounded`, `roundedRectangle`, `patternLinear`, and the wall profile
(after parameterizing the inner wall). Height logic is not shared (its own formula).

### 4.6 Size and risk

**Large.** About 500 Swift lines, more globals than any other file. Risks: the slits (zero volume,
invisible to volume and symmetric-difference checks; need topological checks such as a cross-section
showing two loops, or a ray cast across the slit), fidelity to slicer behavior (only a print test proves
the vase works), the `a_tab` and wall overrides, and the many derived quantities that change branches
(`n_st`, `me > 6`).

### 4.7 Behavior and web-page suggestions

OpenSCAD: bin bottom at z = 0; base spans z = -h_base to 0 plus the cross up to `d_bottom` **(inferred
from `block_base_blank`'s mirrors)**. The preview cannot show the slits; users need slicer settings
(vase mode, `bottom_layer` bottom layers, extrusion width = `nozzle`). Suggestions:

- Two tabs, "Vase bin" and "Vase base", sharing printer settings (nozzle, layer, bottom layers)
  declared in the project body, like the lidded bin's shared settings.
- Put the slicer instructions in `Metadata` description.
- Tab style menu of 7 with a note that heights of 3 units or less have no tabs.
- Base tab: hole toggle and `style_base` ("crosses on the base" only if not "none").
- `a_tab` advanced or fixed at 40. Drop `type` (replaced by tabs).

---

## 5. Cross-cutting

### 5.1 Dependency graph of ports

Legend: `[P]` ported, `[M]` missing, `[~]` partial. Arrows read "is needed by".

```
F0 trivial helpers [M]: pattern_circular, copy_mirror, rounded_square, public clp,
                        fractional patternLinear [~]
F1 Dimensions additions [M]: hole, tab, baseplate constants

H1 block_base_hole(style 1..3, o) [M] ─┐
H2 refined_hole [M] ──────────────────┼─> B1 block_base with holes [~] ─> B2 gridfinityBase [M]
   blockBaseSolid [P] ────────────────┘                                    (dbnx auto, final_cut,
                                                                             only_corners, off)

C1 profile_cutter, profile_cutter_tab, transform_main, transform_tab [M]
C2 fillet_cutter (Minkowski strategy) [M]
C1 + C2 ─> C3 block_cutter [M] ─> C4 cut, cutEqual [M]
cutCylinders [M] needs only placed [P], roundedRectangle [P], patternLinear [P]

BIN  = BinGeometry.shell [P] + B2 + (C4 | cutCylinders | solid)
BASEPLATE = B2 restricted (holes off, off = 0.5, final_cut false) + H1 style 1 only
            + own cutters (weight, skeleton, countersink, counterbore, screw together)
LITE = BIN pieces (C4 with scoop 0, B2 with off < 0, H1 with o) + lite assembly
VASE = wallProfile with inner-wall parameter [~] + blockWall/blockBottom/sweepRounded [P]
       + Mesh tetrahedron + vase modules; needs none of C*, B2, H*
```

Answers to the questions in the brief:

- `block_base` with hole styles unlocks the **bin** fully on the base side. The **baseplate** does not
  need `block_base` holes or `refined_hole`: it calls `gridfinityBase(..., style_hole = 0, off = 0.5,
  final_cut = false)` and only `block_base_hole(1)` (magnet). It needs `gridfinityBase`'s grid
  wrapper.
- Cutters and tabs unlock the **compartment bin** and **lite** (lite cannot be built without them, its
  hollowing subtracts a tall copy of the cutters).
- The **vase** is independent of both.

Suggested order: F0, F1, then B2 + H1 + H2 (ships a solid-interior bin and a cylinder bin on a page),
then baseplate, then C1 to C4 (compartment bin), then lite, then vase.

### 5.2 `$`-variables and globals the port must replace

| OpenSCAD | Used by | Proposed Swift home |
|---|---|---|
| `$gxx $gyy $dh $dh0 $style_lip` | `gridfinityInit`, `cut`, `cut_move`, `block_cutter`, `cutEqual`, `cutCylinders`, `profile_cutter` (`$dh` for scoop radius) | `BinGeometry` (done); cutters become methods on `BinGeometry` |
| `$dh` in vase | `gridfinityVase` sets `$dh = d_height` | `VaseGeometry.height` |
| `$fa = 8`, `$fs = 0.25` | every file | `.withSegmentation(minAngle: 8°, minSize: 0.25)` at the model root, or a quality parameter; LiddedBin uses Cadova's default (2°, 0.15), which is finer than OpenSCAD's |
| `$fn = 64` (references) | `generate.py` | `cornerSegments` and `withSegmentation(count:)` in tests |
| `standard.scad` constants | everywhere | `Dimensions` (extend with holes, tabs) plus a `BaseplateDimensions` |
| `a_tab` (36, vase 40) | `block_cutter`, vase `profile_tab` | `Dimensions.aTab`; vase sets 40 on a copy |
| `d_tabh`, `d_tabw` | cutter, vase | `Dimensions` |
| baseplate globals `screw_together`, `n_screws`, `d_screw`, `d_screw_head`, `screw_spacing` | `calculate_off`, `cutter_screw_together` | `BaseplateConfiguration` |
| lite globals `bottom_layer`, `gridz` (as a radius) | `gridfinityLite` | `LiteConfiguration` |
| vase globals `nozzle layer bottom_layer gridx gridy gridz n_divx enable_* style_tab style_base` and derived `d_bottom x_l d_height f2c me m d_ramp d_edge n_st n_x spacing shift shiftauto xFunc` | nearly every vase module | `VaseConfiguration` (inputs) plus `VaseGeometry` (derived, computed once) |
| bins top-level `gridx ... div_base_y` | entry only | `BinConfiguration` |

### 5.3 Quirks and probable bugs the port must decide on

| # | Where | Behavior | Suggested decision |
|---|---|---|---|
| Q1 | bins 90-97 | compartments need both `divx` and `divy` above 0 (same for cylinders); `divx = 3, divy = 0` silently gives a solid bin | replace with an Interior choice |
| Q2 | bins/lite `height()` call | `style_lip` passed as the lip argument: lip style 2 adds `h_lip` for every height mode | keep (intended "retain height") |
| Q3 | `cut` 93-95 | z shift is `$dh0 - $dh` when `height_internal` is set, so compartments keep full depth and their bottom moves down by `$dh - $dh0`, through the reduced bottom block to the base slab **(inferred)** | verify with a reference; restrict `height_internal` to solid bins |
| Q4 | `block_base` 157-163 | holes at `l/2 - d_hole_from_side` (13 mm) from each sub-foot center even when `dbnx < 1`, so half-size feet (21 mm) get holes outside or at their edge **(inferred)** | verify; possibly only cut holes at full-cell positions |
| Q5 | `block_base` 157 | `pattern_circular(abs(l - d_hole_from_side/2) < 0.001 ? 1 : 4)` compares 42 with 4, never true | drop the branch |
| Q6 | `gridfinityBase` 136-142 | `only_corners` uses `block_base_hole(style_hole)` even for style 4, giving magnet plus screw cylinders, not refined holes, and without the `2*h_slit` lift | decide: match or use `refined_hole` at the corners |
| Q7 | `pattern_linear` 498-505 | `ceil(x)` copies but centered with raw `x`, so `x = 1.5` gives copies at -10.5 and +31.5 (asymmetric, then clipped by `final_cut`); `x = 0` gives the range `[1:0]` (deprecated reversed range; behavior in 2026.10 to check) | port fractional counts faithfully for half-cell bins, guard zero |
| Q8 | lite 60 | `cutEqual` without the `> 0` guard: `divx = 0` divides by zero **(inferred)** | clamp to 1 |
| Q9 | lite + `refined_hole` | lite offsets the core with `off`, but `refined_hole` ignores the offset, so style 4 in lite would leave no boss; the lite file omits 4 from its choices | do not offer 4 for lite |
| Q10 | lite 129 | `rounded_rectangle(gx*1000, gy*1000, gridz*1000, gridz)` uses `gridz` as a corner radius; harmless for a clip block | reproduce as a plain box |
| Q11 | baseplate | `calculate_off` reads the global `screw_together`, not its `sp` argument; skeleton with `sh == 0` adds `d_screw` (a diameter) as a floor height; `hole_pattern` has a bare `render();` (no effect); screw-together holes sit on the grid edge (`gx*42/2`), not the padded plate edge, so with fit-to-drawer padding they are buried **(inferred)**; `gridx = 0` with `distancex < 42` gives `gx = 0`; `d_screw_head` is only spacing (no head recess) | match by default; document the padding case; validate `gx >= 1` |
| Q12 | bins vs baseplate | `style_hole` means foot holes in bins/lite and floor screw holes in the baseplate | distinct Swift names |
| Q13 | vase 131-133 | `block_tabsupport` only when `n_divx < 1`, where `spacing` divides by 0: dead code | drop |
| Q14 | vase 79 | mode 2 subtracts 3.8, not `h_lip` (3.548), so heights differ from the bin file by 0.252 mm | match the vase file in the vase port |
| Q15 | vase | `a_tab = 40` and `profile_wall_sub_sub` overrides apply file-wide (OpenSCAD's last-assignment and last-definition rules) | explicit parameters |
| Q16 | vase 514 | `max(bottom_layer*1)` single-argument `max` (returns the number); `bottom_layer <= 0` handled by a separate cube cut at line 150-152 | match |
| Q17 | vase base | always a 1x1 foot, but the magic slice length uses `l_grid*gridx` | harmless; base page ignores grid size |
| Q18 | vase | `block_flushscoop` defined, never called | drop |
| Q19 | `block_cutter` | `abs(s) > 0` tests allow negative scoop weights; scoop slider declared 0...1 but comment says any real number | clamp 0...1 |
| Q20 | segmentation | Cadova `segmentCount` truncates, OpenSCAD rounds up; differs only where the `$fs` term wins (r under about 1.43 mm at `$fa = 8`) **(inferred)** | use fixed counts in references |

### 5.4 Verification: OpenSCAD reference cases

Method (verified in both packages): `Reference/generate.py` runs OpenSCAD with `-D $fn=64` plus case
defines, writes `reference.json` (volume, min, max from the full-precision ASCII STL) and
`Reference/stl/<case>.stl` (float32-rounded except `FULL_PRECISION` cases);
`GridfinityTestSupport.expectMatchesReference` checks volume (1e-4 relative), bounds (0.05 mm) and
symmetric difference (0.05 mm^3), with `cornerSegments = 16` for parity. The top-level files run their
geometry at include time, so they are run directly with `-D` overrides, as LiddedBin's `generate.py`
does with `lid-bin.scad`. For a quirk the port fixes, LiddedBin's `HOLLOW_PATCH` approach (patch a
copy of the `.scad` and check that only those cases change) applies.

Command shape: `openscad -o case.stl --export-format asciistl -D '$fn=64' -D gridx=2 ... <file>.scad`.
Minkowski cases at `$fn = 64` (sphere of 64 by 32) may be slow; a lower `FN` per case is an option.

Bins (`gridfinity-rebuilt-bins.scad`):

| Case | Defines | Covers |
|---|---|---|
| `bins_default` | (none) | solid 3x2x6, refined holes |
| `bins_1x1x3_holes{1,2,3,4}` | `gridx=1 gridy=1 gridz=3 style_hole=N` (4 cases) | every hole style |
| `bins_2x1x3_div2x1` | `gridx=2 gridy=1 gridz=3 divx=2 divy=1 style_hole=0` | basic cutter, auto tab, scoop |
| `bins_3x2x6_div3x2_full` | `divx=3 divy=2 style_tab=0 style_hole=0` | full tab, interior columns |
| `bins_2x2x6_div1x1_tab{2,3,4,5}` | `gridx=2 gridy=2 divx=1 divy=1 style_tab=N style_hole=0` | partial tab alignment, none |
| `bins_2x2x2_div2x2` | `gridz=2 divx=2 divy=2 style_hole=0` | `zsmall` (no tabs) |
| `bins_lip{1,2}_mode2` | `divx=2 divy=1 style_lip=N gridz_define=2 gridz=40` | lipless cutters, height modes |
| `bins_scoop05_zsnap` | `divx=2 divy=2 scoop=0.5 gridz_define=1 gridz=20 enable_zsnap=true` | scoop scaling, snap |
| `bins_corners_half` | `gridx=1.5 gridy=1 style_hole=2 only_corners=true` | auto `dbnx`, fractional pattern, Q6/Q7 |
| `bins_cyl_{x,z}` | `cdivx=2 cdivy=1 cd=12 ch=10 c_orientation=0` and `=2` | cylinders |
| `bins_internal_div` | `divx=2 divy=2 height_internal=10 style_hole=0` | Q3 |
| `bins_divbase2_holes` | `gridx=1 gridy=1 div_base_x=2 div_base_y=2 style_hole=1` | Q4 |

Baseplate (`gridfinity-rebuilt-baseplate.scad`):

| Case | Defines | Covers |
|---|---|---|
| `bp_thin_2x2` | `gridx=2 gridy=2` | default style |
| `bp_weighted_2x1_cb` | `gridx=2 gridy=1 style_plate=1` | weight pockets, counterbore, magnets |
| `bp_weighted_cs_nomag` | `gridx=1 gridy=1 style_plate=1 style_hole=1 enable_magnet=false` | countersink, no magnet |
| `bp_skeleton_2x2` | `gridx=2 gridy=2 style_plate=2` | skeleton minkowski, `off` table |
| `bp_skeleton_none` | `gridx=1 gridy=1 style_plate=2 style_hole=0` | Q11 (`d_screw` as height) |
| `bp_screw_2x2_n3` | `gridx=2 gridy=2 style_plate=3 n_screws=3` | screw together |
| `bp_screw_min` | `gridx=2 gridy=1 style_plate=4` | minimal |
| `bp_fit_fill` | `gridx=0 gridy=0 distancex=200 distancey=130` | fill drawer |
| `bp_fit_align` | `gridx=2 gridy=2 distancex=100 distancey=90 fitx=1 fity=-0.5` | padding alignment |
| `bp_fit_screw` | `gridx=2 gridy=1 distancex=100 style_plate=3` | Q11 buried screw holes |

Lite (`gridfinity-rebuilt-lite.scad`):

| Case | Defines | Covers |
|---|---|---|
| `lite_default` | (none) | 3x3x6, 2x2, no holes |
| `lite_1x1x3_div1` | `gridx=1 gridy=1 gridz=3 divx=1 divy=1` | single compartment |
| `lite_holes{1,3}` | `gridx=2 gridy=1 style_hole=N` | boss offsets |
| `lite_bottom2` | `bottom_layer=2 gridx=2 gridy=2` | floor thickness |
| `lite_lip1` | `style_lip=1 gridx=2 gridy=1` | lipless |
| `lite_short` | `gridz=2 gridx=2 gridy=1` | `zsmall` |
| `lite_tab0_5` | `style_tab=0` and `style_tab=5` | tab extremes |
| `lite_corners` | `style_hole=2 only_corners=true` | corners |

Vase (`gridfinity-spiral-vase.scad`):

| Case | Defines | Covers |
|---|---|---|
| `vase_default` | (none) | 1x1x6 bin, 2 compartments |
| `vase_base` | `type=1` | base with holes and cross |
| `vase_base_plain` | `type=1 enable_holes=false style_base=4` | base without holes, no cross |
| `vase_2x1_div3_tab{0,1,2,3,6}` | `gridx=2 n_divx=3 style_tab=N` | tab styles |
| `vase_nolip` | `enable_lip=false` | lipless |
| `vase_noextras` | `enable_scoop_chamfer=false enable_funnel=false enable_inset=false enable_pinch=false` | plain shell |
| `vase_short` | `gridz=3 n_divx=2` | `n_st = 6` |
| `vase_2x2_base{1,2,3,4}` | `gridx=2 gridy=2 style_base=N` | X cutout selection |
| `vase_bottom0` | `bottom_layer=0` | zero bottom |
| `vase_nozzle04` | `nozzle=0.4 layer=0.2` | printer settings |

Vase slits need an extra check per case (cross-section at mid height shows the slit as a gap; ray
casts across it). Volume and symmetric difference cannot see them.

### 5.5 Customizer page structure with Cadova

Facts (verified in `WebCustomizer.md` and `action.yml`): a project with several models gets one tab
per model; `--model NAME` (action input `model`) limits a page to one model without tabs; `output` is
relative to the package (default `Customizer`); `upload-pages-artifact` defaults to true and uploads the
output with `actions/upload-pages-artifact@v3`; `cache` caches the toolchain and `.build` (key includes
the hash of the package's `Package.resolved`); the first WASM build takes several minutes; `model.wasm`
is about 18 MB (LiddedBin's is 18,702,805 bytes), about 5 MB compressed. Parameters appear only on
tabs whose model reads them; declarations in the project body are shared by tabs.

| Option | Shape | Cost |
|---|---|---|
| A. One executable, one tab per component | `Project { Model("Bin"); Model("Baseplate"); Model("Lite bin"); Model("Vase bin"); Model("Vase base") }` | one build and one 18 MB WASM for everything; one page heading and one author/license line from the project `Metadata` (a problem if combined with the CC BY 4.0 lidded bin: the rebuilt library is MIT); parameters are per tab automatically; tab count grows (5 plus the lidded bin's 5 if merged) |
| B. One executable, several pages via `model` | same product, the action run once per model with `model:` and a different `output` | each page carries its own copy of the same 18 MB WASM (browsers cache by URL, so no sharing **(inferred)**); one compile, then one link/optimize per run **(inferred)** |
| C. One executable per component (in one package) | products `gridfinity-bin`, `gridfinity-baseplate`, ... in e.g. a `GridfinityCustomizers` package depending on `GridfinityRebuilt` | each page its own WASM of about 18 MB (Cadova and Manifold dominate **(inferred)**); `.build` is shared, so Cadova compiles for WASM once per package; per-product link and Binaryen pass each run; each page has its own metadata and license |
| D. One package per component | as LiddedBin is now | separate `.build` caches, so each package compiles Cadova for WASM on a cold cache (several minutes each) |

Publishing several customizers under one GitHub Pages site (one site per repository, and the existing
LiddedBin page is at the site root, `https://xeresrazor.github.io/Cadovafinity/`):

1. In one job: run `tomasf/Cadova/Actions/BuildCustomizer@1.3.0` once per customizer with
   `upload-pages-artifact: 'false'`, each with its `package-path`, `product`, optional `model`, and an
   `output` inside its package (for example `Customizer/bin`). Then a shell step copies each `path`
   output into `_site/<name>/`, writes `_site/index.html` linking them (or keeps LiddedBin at the root),
   then `actions/upload-pages-artifact@v3` with `path: _site` once, then `actions/deploy-pages@v4`.
   Only one `github-pages` artifact may be uploaded per run, which is why the per-run upload must be off
   **(inferred from how upload-pages-artifact names its artifact)**. Unverified: whether a second action
   run in the same job reinstalls the toolchain cleanly when the first run had a cache miss (the install
   step runs `swiftly init` again).
2. Or one job per customizer (parallel, each `upload-pages-artifact: 'false'` plus
   `actions/upload-artifact`), and a final job that downloads all, assembles `_site`, uploads the pages
   artifact and deploys. Faster wall clock, more runner minutes, robust against the toolchain question.

Either way, each customizer subfolder is self-contained (its `index.html`, `model.wasm`,
`licenses.html`), so relative links between them work.
