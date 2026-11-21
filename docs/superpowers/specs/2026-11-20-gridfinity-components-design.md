# Gridfinity components as customizers: design

## Goal

Publish every component of the original gridfinity-rebuilt-openscad library as a web customizer built with Swift and Cadova, next to the lidded bin: the baseplate, the standard bin, the lite bin and the spiral vase bin. Each customizer is verified against the original OpenSCAD output, as the lidded bin is.

The component inventory (`docs/superpowers/notes/2026-11-20-gridfinity-component-inventory.md`) lists every parameter, module, port status and quirk. This document records the decisions that follow from it.

## Components

| Component | Source file | Size | Needs from the shared library |
|---|---|---|---|
| Baseplate | `gridfinity-rebuilt-baseplate.scad` | medium-small | base-grid wrapper, plain magnet hole, its own cutters (weights, skeleton, screws, counterbore, countersink, fit to drawer) |
| Standard bin | `gridfinity-rebuilt-bins.scad` | large | base-grid wrapper, hole styles 1 to 4, compartment cutters (tab styles 0 to 5, scoop, fillets), cylinder cutouts |
| Lite bin | `gridfinity-rebuilt-lite.scad` | medium | the bin's cutters (built three times), offset base grid |
| Spiral vase bin | `gridfinity-spiral-vase.scad` | large | wall profile with an inner-wall parameter, its own modules; independent of the cutters |
| Lidded bin | `lid-bin.scad` (smkent) | done | |

## Packages

- `GridfinityRebuilt` (exists, MIT): gains the shared modules the components need: helpers (`patternCircular`, `copyMirror`, fractional `patternLinear`), the extra `Dimensions` constants (holes, tabs, baseplate), the base-grid wrapper with the hole styles and the refined hole, and the compartment cutters. It keeps the rule that nothing in it uses `@Parameter`.
- `GridfinityCustomizers` (new, MIT, a sibling of `LiddedBin`): a model library `GridfinityModels` holding a configuration type, validation and geometry per component, and one executable per component that declares the customizer parameters: `gridfinity-baseplate`, `gridfinity-bin`, `gridfinity-lite`, `gridfinity-vase`. It depends on `GridfinityRebuilt`.
- `LiddedBin` (exists, CC BY 4.0) stays a separate package because its license differs.

Pattern per component, as in `LiddedBin`: a plain configuration struct with `validated()`, an input type the customizer fills, a design value holding derived numbers, and a thin executable. The `openSCADOriginal`-style preset idea applies wherever this port deliberately deviates from the original.

## Publishing

One GitHub Pages site for the repository, with one customizer page per component. Each page is its own Cadova product, with its own 18 MB WebAssembly file (about 5 MB compressed), its own metadata and its own license line.

| URL under `https://xeresrazor.github.io/Cadovafinity/` | Page |
|---|---|
| `bins/lidded/` | Lidded bin (moves from the site root) |
| `bins/standard/` | Standard bin |
| `bins/lite/` | Lite bin |
| `bins/vase/` | Spiral vase bin |
| `baseplate/` | Baseplate (not a bin, so outside `bins/`) |
| `/` | A redirect to `bins/lidded/`, so existing links keep working |

The workflow runs Cadova's `BuildCustomizer` action once per customizer, in separate parallel jobs, each with `upload-pages-artifact: 'false'` and its own `package-path`, `product` and `output`. A final job downloads the outputs, assembles one `_site` tree with the layout above, uploads it once and deploys. Parallel jobs avoid depending on a second action run reinstalling the toolchain cleanly in one job (unverified), and cost more runner minutes. The landing page (`XeresRazor.github.io`) gets one card per page.

## Behavior decisions

The port matches the original unless it is clearly a defect, keeps each deviation behind a patched OpenSCAD reference, and documents it, as `LiddedBin` does. The quirk table in the inventory (section 5.3) lists 20 cases; the ones that shape the design:

- Compartment counts (bin and lite): minimum 1 on each axis, with an explicit choice for a solid interior and a cylinder interior, replacing the original's rule that a single zero count silently gives a solid bin (Q1, Q8).
- `height_internal` is offered only with a solid interior, because the compartments otherwise reach through the bottom block (Q3, to verify against a reference first).
- Scoop weight is clamped to 0 to 1 (Q19). The baseplate's `style_hole` and the bin's `style_hole` get distinct names (Q12).
- The vase's file-wide overrides (`a_tab` 40, the inner wall width, the 3.8 height constant) become explicit parameters of its own configuration, not changes to the shared wall profile (Q14, Q15).
- Lite does not offer hole style 4 (Q9).
- Dead code is dropped (Q13, Q18). Everything else stays as the original unless a reference shows otherwise; a spike decides each inferred quirk (Q3, Q4, Q7, Q11) before the port commits to it.

## Verification

The method of the lidded bin applies: a `Reference/generate.py` per package runs OpenSCAD with `-D` overrides for 5 to 10 reference cases per component, and `expectMatchesReference` checks volume (1e-4 relative), bounds (0.05 mm) and mesh symmetric difference (0.05 mm^3 unless a case records its own measured limit), with fixed segment counts. Additions:

- **Cutter fillets.** OpenSCAD builds them with Minkowski, which Cadova lacks. A spike builds a cutter both ways (a 3D round offset, and exact convex pieces equivalent to the Minkowski sum with the OpenSCAD sphere) and compares each with the OpenSCAD output. Production uses the exact construction if it is fast enough in WebAssembly; otherwise the offset, with a per-case tolerance recorded.
- **Spiral vase.** The 0.001 mm magic slices add almost no volume, so volume and mesh checks cannot see them. The vase tests also compare per-layer cross-section areas against slices of the OpenSCAD output.
- **Segmentation.** OpenSCAD uses `$fa = 8` and `$fs = 0.25`; Cadova's default is finer. The first phase decides one policy for all the new pages (a root `withSegmentation(minAngle: 8°, minSize: 0.25)` matching OpenSCAD, or Cadova's default for smoother parts) and records the measured build time; references use fixed counts either way.
- Cross-sections are rendered with `render_section.py` and looked at for every new geometry class, as for the lid fit.

## Phases

Each phase gets its own plan, tests and commits, and ends with the page published.

1. **Foundations, publishing and baseplate.** Shared helpers and constants; the base-grid wrapper with hole styles 1 to 3 and the refined hole; the multi-page publishing workflow and the move of the lidded bin to `bins/lidded/` with a redirect; the `GridfinityCustomizers` package; the baseplate customizer. Exit: the baseplate and the lidded bin are both live at their new addresses, and the landing page links both.
2. **Standard bin.** Solid and cylinder interiors with holes; then the compartment cutters (spike first), tab styles, scoop and fillets. Exit: `bins/standard/` live.
3. **Lite bin.** Exit: `bins/lite/` live.
4. **Spiral vase bin.** Exit: `bins/vase/` live.

## Risks and open points

- Cutter fillets without Minkowski (spike in phase 2). Possible slow builds in WebAssembly; the build-time method of the lidded bin applies (native first, then the page).
- The vase's magic slices and file-wide overrides.
- Four more 18 MB downloads on the site. Each page is separate, so a visitor downloads only the one they open.
- Licenses on the pages: the new pages carry MIT with credit to Kenneth Hodson (gridfinity-rebuilt-openscad) and to Zachary Freedman and Voidstar Lab LLC (Gridfinity); the lidded bin keeps CC BY 4.0 with credit to smkent.
- Names: the plain bin is `standard` in URLs and code; the baseplate sits outside `bins/`. Both are one-word changes if a different name is wanted.
