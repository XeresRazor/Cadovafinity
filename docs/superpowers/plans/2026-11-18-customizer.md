# Lidded Bin Web Customizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the lidded bin as a Cadova web customizer: a static page where a visitor adjusts the bin's options, sees a live 3D preview and downloads the bin, the lid or the open assembly.

**Architecture:** The model library (`LiddedBinModel`) stays free of `@Parameter`. It gains input validation (a `validated()` clamp), `ParameterChoice` conformances for its option enums, and a height-input type that turns three height conventions into one `HeightMode` plus value. The `lidded-bin` executable declares every `@Parameter` once in the `Project` (so both model tabs share values), maps them to a `LiddedBinConfiguration`, and builds three `Model`s (Bin, Lid, Open assembly). `swift package generate-customizer` compiles it to WebAssembly. A GitHub Actions workflow publishes the result to GitHub Pages.

**Tech Stack:** Swift 6.3 package manifest, Cadova 1.3 (`Parameter`, `ParameterChoice`, `Metadata`, `Project`), Swift 6.4.0 WebAssembly toolchain from swift.org (build step only), Binaryen, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-11-17-cadova-gridfinity-port-design.md` (Web customizer section). Prior plans: `2026-11-17-library-core.md`, `2026-11-18-lidded-bin.md`. Cadova's customizer guide: `/Users/shinohara/Downloads/3D Printing/Cadova/Cadova/Sources/Cadova/Cadova.docc/WebCustomizer.md`.

## Global Constraints

- The model library never uses `@Parameter`. All `@Parameter` declarations live in `Sources/lidded-bin/main.swift` (or a file in that target).
- Every target that imports Cadova has `swiftSettings: [.interoperabilityMode(.Cxx)]`.
- WebAssembly limits (from the Cadova guide): `Text` only with bundled fonts (the model uses no text), no ICU (`DateFormatter`/`NumberFormatter` stop the build), models build on a single thread, and the browser gives less stack space. No resources are used. Do not add `Foundation` features beyond math.
- The customizer page lists a parameter on a model's tab only when that model reads it; parameters declared in the `Project` are shared between tabs.
- Parameter labels are plain English with the OpenSCAD name in the description where one exists. Units use the `unit:` argument.
- Attribution: the page shows the design's author and license through `Metadata`. The design is smkent's CC BY 4.0 model; the metadata must credit smkent and name the license. Do not remove or shorten the attribution text in the README.
- Commits: the user allowed committing each step of this work. Commit after each task with the repo-local identity (`XeresRazor <shinohara@gmail.com>`, signing off, already configured in this repo). One commit per task, message style matching the existing log. Never `git push`, never amend, never commit `.build`, `Reference/stl`, `Models`, `Customizer` or `.superpowers` (all gitignored).
- Build offline with `swift test --skip-update` from each package. Network-needing steps are marked **NETWORK** and are run by or with the user (see Task 7); never edit sandbox allowlists.
- No em dashes in comments, docs or READMEs.
- Reference verification still applies: any geometry change is checked against OpenSCAD references with the existing tolerances (volume 1e-4 relative, bounds 0.05 mm, symmetric difference 0.05 mm³ unless a documented override).

## Decisions made in this plan (the user may reverse them)

1. **Models:** three tabs: `Bin`, `Lid`, `Bin and lid (open)`. The closed assembly is not offered, since it interpenetrates by 1.4 mm³ (as in the original). Both assembly parts are separate objects in the 3MF, so slicers keep them separate.
2. **Input handling:** the library clamps to safe values (`validated()`), and the customizer ranges keep visitors inside them. Clamping is silent in the library but never needed for in-range input.
3. **Height:** one `Height style` choice with three conditional height controls (units, internal mm, external mm), each with its own range.
4. **Limits:** grid size and dividers have ranges chosen from the measured build time in Task 3, not guessed.
5. **License text:** `LiddedBin` metadata says CC BY 4.0 (a derivative of a CC BY 4.0 design). The library license file is added only after the user confirms upstream's license (Task 6).

## File Structure

```
LiddedBin/
  Package.swift                                  # (unchanged unless Task 3 or 7 requires)
  Sources/LiddedBinModel/
    Validation.swift                             # LiddedBinConfiguration.validated(), limits
    ParameterChoices.swift                       # ParameterChoice conformances, HeightStyle
    CustomizerInput.swift                        # LiddedBinInput -> LiddedBinConfiguration
  Sources/lidded-bin/main.swift                  # Project with @Parameters and three Models
  Tests/LiddedBinModelTests/
    ValidationTests.swift
    CustomizerInputTests.swift
    BuildTimeTests.swift                         # opt-in benchmark (Task 3)
  README.md                                      # + Customizer section
  LICENSE                                        # Task 6
.github/workflows/customizer.yml                 # at the repo root, Task 6
```

---

### Task 1: Input validation

**Files:**
- Create: `LiddedBin/Sources/LiddedBinModel/Validation.swift`
- Test: `LiddedBin/Tests/LiddedBinModelTests/ValidationTests.swift`

**Interfaces:**
- Produces:
  - `public struct LiddedBinLimits: Sendable` with `static let gridSize: ClosedRange<Int>`, `dividers: ClosedRange<Int>`, `divMultiple: ClosedRange<Double>`, `unitsHeight: ClosedRange<Double>`, `internalHeight: ClosedRange<Double>`, `externalHeight: ClosedRange<Double>`. Values are placeholders set by Task 3; until then use `gridSize 1...6`, `dividers 0...12`, `divMultiple 1...5`, `unitsHeight 1...12`, `internalHeight 5...80`, `externalHeight 14...100`.
  - `public extension LiddedBinConfiguration { func validated() -> LiddedBinConfiguration }`: clamps `gridX`/`gridY` to `gridSize`, `divX`/`divY` to `dividers`, `divMultiple` to `1...5`, `gridZ` to the range of the current `heightMode`, and `internalHeightOverride` to `0...storageHeight`. `validated()` is idempotent and leaves in-range input unchanged.
- Consumes: existing `LiddedBinConfiguration`, `HeightMode`, `LiddedBinDesign.storageHeight`.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import LiddedBinModel
import GridfinityRebuilt

struct ValidationTests {
    @Test func `in-range configuration is unchanged`() {
        var c = LiddedBinConfiguration()
        c.gridX = 3; c.gridY = 2; c.gridZ = 4; c.divX = 4; c.divY = 2
        #expect(c.validated().gridX == 3)
        #expect(c.validated().divX == 4)
        #expect(c.validated().gridZ == 4)
    }

    @Test func `grid sizes are clamped to the supported range`() {
        var c = LiddedBinConfiguration()
        c.gridX = 0; c.gridY = 99
        let v = c.validated()
        #expect(v.gridX == LiddedBinLimits.gridSize.lowerBound)
        #expect(v.gridY == LiddedBinLimits.gridSize.upperBound)
    }

    @Test func `dividers and multiple are clamped`() {
        var c = LiddedBinConfiguration()
        c.divX = -4; c.divY = 500; c.divMultiple = 0
        let v = c.validated()
        #expect(v.divX == 0)
        #expect(v.divY == LiddedBinLimits.dividers.upperBound)
        #expect(v.divMultiple == 1)
    }

    @Test func `height is clamped to the range of its mode`() {
        var c = LiddedBinConfiguration()
        c.heightMode = .internalMillimeters
        c.gridZ = 1000
        #expect(c.validated().gridZ == LiddedBinLimits.internalHeight.upperBound)
        c.heightMode = .units
        c.gridZ = -3
        #expect(c.validated().gridZ == LiddedBinLimits.unitsHeight.lowerBound)
    }

    @Test func `internal height override cannot exceed the storage height`() {
        var c = LiddedBinConfiguration()
        c.internalHeightOverride = 10_000
        let v = c.validated()
        #expect(v.internalHeightOverride <= LiddedBinDesign(v).storageHeight)
        #expect(c.validated().validated().internalHeightOverride == v.internalHeightOverride)
    }

    @Test func `validated is idempotent`() {
        var c = LiddedBinConfiguration()
        c.gridX = 0; c.divX = 99; c.divMultiple = 9; c.gridZ = 500
        #expect(c.validated().validated().gridX == c.validated().gridX)
        #expect(c.validated().validated().gridZ == c.validated().gridZ)
    }
}
```

- [ ] **Step 2: Run, expect a build error** (`validated`, `LiddedBinLimits` missing): `swift test --skip-update --filter ValidationTests` from `LiddedBin/`.

- [ ] **Step 3: Implement**

```swift
import GridfinityRebuilt

/// The ranges the model accepts. The customizer offers the same ranges, so a visitor cannot leave them.
public struct LiddedBinLimits: Sendable {
    public static let gridSize = 1...6
    public static let dividers = 0...12
    public static let divMultiple = 1.0...5.0
    public static let unitsHeight = 1.0...12.0
    public static let internalHeight = 5.0...80.0
    public static let externalHeight = 14.0...100.0

    public static func heightRange(for mode: HeightMode) -> ClosedRange<Double> {
        switch mode {
        case .units: unitsHeight
        case .internalMillimeters: internalHeight
        case .externalMillimeters: externalHeight
        }
    }
}

public extension LiddedBinConfiguration {
    /// A copy with every value clamped to what the model supports. In-range input is returned unchanged.
    func validated() -> LiddedBinConfiguration {
        var c = self
        c.gridX = min(max(c.gridX, LiddedBinLimits.gridSize.lowerBound), LiddedBinLimits.gridSize.upperBound)
        c.gridY = min(max(c.gridY, LiddedBinLimits.gridSize.lowerBound), LiddedBinLimits.gridSize.upperBound)
        c.divX = min(max(c.divX, LiddedBinLimits.dividers.lowerBound), LiddedBinLimits.dividers.upperBound)
        c.divY = min(max(c.divY, LiddedBinLimits.dividers.lowerBound), LiddedBinLimits.dividers.upperBound)
        c.divMultiple = min(max(c.divMultiple, LiddedBinLimits.divMultiple.lowerBound), LiddedBinLimits.divMultiple.upperBound)
        let heights = LiddedBinLimits.heightRange(for: c.heightMode)
        c.gridZ = min(max(c.gridZ, heights.lowerBound), heights.upperBound)
        let storage = LiddedBinDesign(c).storageHeight
        c.internalHeightOverride = min(max(c.internalHeightOverride, 0), max(storage, 0))
        return c
    }
}
```

Note that `LiddedBinDesign.init` must not itself call `validated()` (the design stays a literal port; callers validate).

- [ ] **Step 4: Run, expect PASS.** Then run the full suite: all previous tests still pass (they use in-range configs; `cornerSegments` is not touched by `validated()`).

- [ ] **Step 5: Commit**: `git add LiddedBin/Sources/LiddedBinModel/Validation.swift LiddedBin/Tests/LiddedBinModelTests/ValidationTests.swift && git commit -m "Add input validation for the lidded bin configuration"`.

---

### Task 2: Parameter choices and the customizer input type

**Files:**
- Create: `LiddedBin/Sources/LiddedBinModel/ParameterChoices.swift`
- Create: `LiddedBin/Sources/LiddedBinModel/CustomizerInput.swift`
- Test: `LiddedBin/Tests/LiddedBinModelTests/CustomizerInputTests.swift`

**Interfaces:**
- Produces:
  - `extension InteriorStyle, LipGrips, LidOrientation, CompartmentPattern: ParameterChoice` (their raw values are `String`, they are `CaseIterable`; add `displayName`). Display names: `minimal` "Minimal", `partialRaised` "Partially raised"; `none` "None", `x` "Along X", `y` "Along Y", `xy` "Along X and Y"; `up` "Up", `down` "Down", `left` "Left", `right` "Right"; `grid` "Equal grid", `multiSize` "Two sizes".
  - `public enum HeightStyle: String, ParameterChoice, Sendable { case sevenMillimeterUnits, internalHeight, externalHeight }` with display names "7 mm units", "Internal height", "Overall height", and `var mode: HeightMode`.
  - `public struct LiddedBinInput: Sendable` with the plain values the customizer collects: `gridX`, `gridY: Int`, `heightStyle: HeightStyle`, `unitsHeight: Double`, `internalHeight: Double`, `externalHeight: Double`, `snapHeight: Bool`, `internalBlockHeight: Double`, `lipGrips`, `lidOrientation`, `interiorStyle`, `compartmentPattern`, `divX`, `divY: Int`, `divMultiple: Double`. Defaults equal `LiddedBinConfiguration()` defaults (gridX/Y 2, units height 3, snap false, grips xy, orientation left, minimal, grid 6x6, multiple 2).
  - `LiddedBinInput.configuration -> LiddedBinConfiguration` (already `validated()`), picking `gridZ` from the field that matches `heightStyle`.
- Consumes: Task 1 `validated()`, the existing enums.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

struct CustomizerInputTests {
    @Test func `default input equals the default configuration`() {
        let c = LiddedBinInput().configuration
        let d = LiddedBinConfiguration()
        #expect(c.gridX == d.gridX && c.gridY == d.gridY && c.gridZ == d.gridZ)
        #expect(c.heightMode == d.heightMode && c.snapHeight == d.snapHeight)
        #expect(c.lipGrips == d.lipGrips && c.lidOrientation == d.lidOrientation)
        #expect(c.interiorStyle == d.interiorStyle && c.compartmentPattern == d.compartmentPattern)
        #expect(c.divX == d.divX && c.divY == d.divY && c.divMultiple == d.divMultiple)
        #expect(c.internalHeightOverride == d.internalHeightOverride)
    }

    @Test func `height style selects the matching field and mode`() {
        var i = LiddedBinInput()
        i.heightStyle = .internalHeight; i.internalHeight = 20; i.unitsHeight = 9
        #expect(i.configuration.heightMode == .internalMillimeters)
        #expect(i.configuration.gridZ == 20)
        i.heightStyle = .externalHeight; i.externalHeight = 30
        #expect(i.configuration.heightMode == .externalMillimeters)
        #expect(i.configuration.gridZ == 30)
        i.heightStyle = .sevenMillimeterUnits
        #expect(i.configuration.heightMode == .units)
        #expect(i.configuration.gridZ == 9)
    }

    @Test func `out-of-range input is clamped`() {
        var i = LiddedBinInput()
        i.gridX = 100; i.divMultiple = 0
        #expect(i.configuration.gridX == LiddedBinLimits.gridSize.upperBound)
        #expect(i.configuration.divMultiple == 1)
    }

    @Test func `choices have unique string raw values and display names`() {
        func check<T: ParameterChoice>(_: T.Type) {
            let raws = T.allCases.map { String($0.rawValue) }
            #expect(Set(raws).count == raws.count)
            #expect(T.allCases.allSatisfy { !$0.displayName.isEmpty })
        }
        check(InteriorStyle.self); check(LipGrips.self); check(LidOrientation.self)
        check(CompartmentPattern.self); check(HeightStyle.self)
    }

    @Test func `readable display names`() {
        #expect(LipGrips.xy.displayName == "Along X and Y")
        #expect(HeightStyle.externalHeight.displayName == "Overall height")
    }
}
```

- [ ] **Step 2: Run, expect build errors.**

- [ ] **Step 3: Implement** `ParameterChoices.swift` (conformances with `displayName` overrides; the enums already declare `String` raw values and `CaseIterable`) and `CustomizerInput.swift`. If the compiler requires `Sendable`/`@retroactive`, adjust and note it. `LiddedBinInput.configuration`:

```swift
public var configuration: LiddedBinConfiguration {
    var c = LiddedBinConfiguration()
    c.gridX = gridX; c.gridY = gridY
    c.heightMode = heightStyle.mode
    c.gridZ = switch heightStyle {
        case .sevenMillimeterUnits: unitsHeight
        case .internalHeight: internalHeight
        case .externalHeight: externalHeight
    }
    c.snapHeight = snapHeight
    c.internalHeightOverride = internalBlockHeight
    c.lipGrips = lipGrips; c.lidOrientation = lidOrientation
    c.interiorStyle = interiorStyle; c.compartmentPattern = compartmentPattern
    c.divX = divX; c.divY = divY; c.divMultiple = divMultiple
    return c.validated()
}
```

`snapHeight` only applies in the mm modes in practice; in units mode OpenSCAD's snapping is a no-op for multiples of 7, so passing it through is harmless. Keep one assertion on that: units mode with snap on gives the same storage height as with it off.

- [ ] **Step 4: Run the full suite, expect PASS.**

- [ ] **Step 5: Commit**: `git add LiddedBin/Sources/LiddedBinModel LiddedBin/Tests && git commit -m "Add parameter choices and customizer input mapping for the lidded bin"`.

---

### Task 3: Build-time benchmark and limits

The browser is single-threaded and slower than native. Choose the ranges from measurement, not guesswork.

**Files:**
- Create: `LiddedBin/Tests/LiddedBinModelTests/BuildTimeTests.swift` (opt-in)
- Modify: `LiddedBin/Sources/LiddedBinModel/Validation.swift` (limits)
- Create: `docs/superpowers/notes/2026-11-customizer-build-times.md` (measured table)

**Interfaces:**
- Consumes: `LiddedBinDesign.geometry(for:)`, `ModelFileGenerator.evaluate`.
- Produces: final `LiddedBinLimits` values and a table of native build times.

- [ ] **Step 1:** Add an opt-in test, enabled only when the environment variable `LIDDED_BIN_BENCH=1` is set (`@Test(.enabled(if: ProcessInfo.processInfo.environment["LIDDED_BIN_BENCH"] == "1"))`), that builds `bin`, `lid` and `bothOpen` for these configurations with Cadova's default segmentation (the production setting) and prints wall time and volume: 1x1x1; 2x2x3 default (6x6 dividers); 3x3x3 (6x6); 4x4x4 (6x6); 6x6x3 (6x6); 6x6x6 (6x6); 6x6x6 (12x12); 6x6x12 (6x6). Run each three times and record the median.
- [ ] **Step 2:** Run `LIDDED_BIN_BENCH=1 swift test --skip-update --filter BuildTime` and record the table in `docs/superpowers/notes/2026-11-customizer-build-times.md` (native time per configuration, machine, date).
- [ ] **Step 3: Decide limits.** Rule: the default configuration and any configuration inside the ranges must build natively in under 5 seconds for a Bin, since WebAssembly on one thread is typically several times slower and a visitor drags sliders. Set `LiddedBinLimits.gridSize`, `dividers`, and the height ranges to the largest values that satisfy the rule, never below `gridSize 1...4`, `dividers 0...8`, and units height `1...8`. If a combination is slow while its parts are not (large grid with many dividers), note it in the table and, if needed, cap the product `gridX * gridY * divX * divY` in `validated()` with a test. Update Task 1's tests to the final constants (they refer to the constants by name, so only the numeric defaults in the plan change).
- [ ] **Step 4:** Full suite passes. If any benchmark configuration in the final ranges fails to build or takes over 15 seconds, report it before continuing: the customizer plan's feasibility depends on it.
- [ ] **Step 5: Commit**: `git add LiddedBin docs && git commit -m "Measure build times and set customizer limits"`.

---

### Task 4: Project with parameters and three models

**Files:**
- Modify: `LiddedBin/Sources/lidded-bin/main.swift`
- Test: `LiddedBin/Tests/LiddedBinModelTests/CustomizerInputTests.swift` (add a test that the parameter defaults are the model defaults, via `LiddedBinInput()`)

**Interfaces:**
- Consumes: `LiddedBinInput`, `LiddedBinDesign.geometry(for:)`, `LiddedBinPart`.
- Produces: the executable's `Project`.

- [ ] **Step 1: Write `main.swift`.** Read `$CADOVA/Sources/Cadova/Cadova.docc/WebCustomizer.md` and `ModelAndProject.md` first (`$CADOVA` is `/Users/shinohara/Downloads/3D Printing/Cadova/Cadova`). Structure:

```swift
import Cadova
import LiddedBinModel

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
    @Parameter("Grid width", in: LiddedBinLimits.gridSize, unit: "cells", description: "Bin width in 42 mm Gridfinity cells (gridx)")
    var gridX = 2
    @Parameter("Grid depth", in: LiddedBinLimits.gridSize, unit: "cells", description: "Bin depth in 42 mm Gridfinity cells (gridy)")
    var gridY = 2

    // Height
    @Parameter("Height style", description: "What the height value means (gridz_define)")
    var heightStyle = HeightStyle.sevenMillimeterUnits
    // ... conditional height parameters, snap, lid and compartment parameters ...

    let input = LiddedBinInput(/* all parameter values */)
    let design = LiddedBinDesign(input.configuration)

    await Model("Bin") { design.geometry(for: .bin) }
    await Model("Lid") { design.geometry(for: .lid) }
    await Model("Bin and lid (open)") { design.geometry(for: .bothOpen) }
}
```

Parameters read by the project body itself would appear on every tab (the guide says a parameter read in the project's own content belongs to every model). That is what is wanted for the shared ones (size, height, lid orientation, grips), but NOT for the bin-only ones (dividers, interior style, compartment pattern) if they should not clutter the Lid tab. So read the bin-only parameters only inside the `Bin` and `Open assembly` model closures, not in the project body: build `design` inside each model with the shared values plus that model's own reads. The Lid model must read only `gridX`, `gridY`, the height parameters, lip grips and lid orientation (and not the interior or compartment ones; the lid does not depend on them). Verify on the generated page (Task 7) that the Lid tab shows no divider controls; if the Cadova rule makes that impossible, report it and accept the extra controls.

Parameter details (labels, ranges, defaults; ranges come from `LiddedBinLimits`):
- `Height style` (choice): "7 mm units" default.
- Conditional height parameters, shown only for their style (declare each inside a `switch heightStyle` as in the guide): `Height` (7 mm units, `LiddedBinLimits.unitsHeight`, step 1, unit "units", default 3), `Internal height` (mm, `internalHeight`, step 1, default 20), `Overall height` (mm, `externalHeight`, step 1, default 30), and `Snap to 7 mm` (Bool, default false) for the two mm styles.
- `Internal block height` (mm, `0...80`, default 0, description "Overrides the internal block height of the bin for solid containers; leave 0 for the default (height_internal)").
- `Lid direction` (choice, default left), `Lip grips` (choice, default xy), `Interior style` (choice, default minimal, Bin tabs only).
- `Compartments` (choice grid/multiSize, default grid), `Dividers X` and `Dividers Y` (Int, `LiddedBinLimits.dividers`, default 6, description "0 gives one open compartment with no dividers"), `Size multiple` (Double, `LiddedBinLimits.divMultiple`, step 0.5, default 2, shown only when Compartments is two sizes).

Because parameters declared in a `switch` appear only while their case is active, keep the three height parameters and the multiple inside `switch`/`if` blocks as the guide shows, and read them back with defaults for the inactive ones.

- [ ] **Step 2: Native smoke test.** `swift run --skip-update lidded-bin` still writes the three models to `LiddedBin/Models/` (clear stale `Bin and lid, closed.3mf`, `Bin and lid, open.3mf` and `Bin slice.3mf` first or note them as stale). The `Bin.3mf` and `Lid.3mf` volumes must equal the previous default outputs (within 1e-4 relative).
- [ ] **Step 3:** Add a test in `CustomizerInputTests` asserting that `LiddedBinInput()` defaults equal the defaults declared in `main.swift` (keep a `static let defaults` in `LiddedBinInput` and use it from `main.swift` for every `@Parameter` default so there is one source of truth).
- [ ] **Step 4:** Full suite passes. Update the README.
- [ ] **Step 5: Commit**: `git add LiddedBin && git commit -m "Declare customizer parameters and three models in the lidded-bin project"`.

---

### Task 5: Production quality and preview versus download

**Files:**
- Modify: `LiddedBin/Sources/lidded-bin/main.swift`
- Test: `LiddedBin/Tests/LiddedBinModelTests/ProductionTests.swift` (extend only if geometry changes)

**Interfaces:**
- Consumes: Cadova's `Environment`/segmentation and `@Environment(\.buildDestination)`.

- [ ] **Step 1:** Measure native build time and symmetric difference of the default Bin/Lid at Cadova's default segmentation versus finer settings (the Task 8 production test already records the default: bin sym diff 3.4 mm³, lid 0.58 mm³). Decide whether a `Quality` parameter (draft / standard / fine, as in the guide's example) is warranted. Rule: add it only if the preview at `standard` takes over 3 seconds natively for the default 2x2x3 bin; otherwise keep one quality and do not add the parameter.
- [ ] **Step 2:** If added, map `Quality` to Cadova segmentation through `.withSegmentation(...)`, default `standard` = today's default, and add a test that `standard` equals the current production geometry volume within 1e-9.
- [ ] **Step 3:** Do not make preview and download differ unless Step 1 shows a need (the guide asks for few, obvious differences). Record the outcome in the README.
- [ ] **Step 4:** Suite passes. **Step 5: Commit** (`Decide customizer quality settings`), even if the decision is "no change" and only the README note was added.

---

### Task 6: Licensing, workflow and README

**Files:**
- Create: `LiddedBin/LICENSE` (CC BY 4.0 notice file) and, only after user confirmation, `GridfinityRebuilt/LICENSE`
- Create: `.github/workflows/customizer.yml` (repo root)
- Modify: `LiddedBin/README.md`, `GridfinityRebuilt/README.md`
- Modify: `.gitignore` (confirm `Customizer/`)

**Interfaces:** none.

- [ ] **Step 1: Licenses.** `LiddedBin/LICENSE` states the work is a port of smkent's CC BY 4.0 design, links `https://creativecommons.org/licenses/by/4.0/`, and names the changes. Do NOT invent a library license. The `gridfinity-rebuilt-openscad` copy in `Lidded Bins/` has no license file; upstream is believed to be MIT. Ask the user to confirm it from the upstream repository (the sandbox cannot reach GitHub). Until confirmed, `GridfinityRebuilt` gets no `LICENSE` and the README keeps its "to be confirmed" wording. Report this as an open item.
- [ ] **Step 2: Workflow.** Use the workflow from the Cadova guide verbatim, with the action version matching the Cadova pin in `Package.resolved` (`tomasf/Cadova/Actions/BuildCustomizer@1.3.0` if the pin is 1.3.0; read the pin), `package-path: LiddedBin`, `product: lidded-bin`, and `source-url` pointing at the repository (ask the user for the GitHub URL; use an empty string and say so if unknown). Place the file at `.github/workflows/customizer.yml` at the repo root and confirm `LiddedBin/Package.swift`'s `.package(path: "../GridfinityRebuilt")` resolves in the action (both folders are in the same checkout).
- [ ] **Step 3: Package.resolved.** The action reads the Cadova version from `Package.resolved`. Run `swift package resolve` in `LiddedBin` (**NETWORK** if it needs to fetch; the cache normally suffices) and confirm `Package.resolved` lists every dependency (Apus, CadovaLiveLink, Pelagos, ThreeMF, Zip, manifold-swift) rather than only `cadova`. Commit the file.
- [ ] **Step 4: README.** Add a "Customizer" section: what the page offers, the three tabs, the parameter table (label, range, OpenSCAD name), the build command (`swift package generate-customizer`), local preview (`python3 -m http.server --directory Customizer 8000`), publishing through the workflow, attribution, and the known WebAssembly limits (no text, single thread).
- [ ] **Step 5: Commit**: `git add .github LiddedBin GridfinityRebuilt .gitignore && git commit -m "Add customizer workflow, license notice and README"`.

---

### Task 7: Build the customizer (NETWORK, with the user)

This task needs tools and downloads the sandbox blocks. Do the preparation, stop, and hand the user exactly what to run.

**Needs from the user (state this plainly when you reach the task):**
1. The Swift **6.4.0** toolchain from swift.org installed (the Xcode Swift cannot be used for the WebAssembly build). Options: `swiftly install 6.4.0`, or the macOS package `https://download.swift.org/swift-6.4.0-release/xcode/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-osx.pkg`. It does not need to be the default toolchain.
2. Network for `generate-customizer`, which downloads the Swift WebAssembly SDK from `download.swift.org` and Binaryen from `github.com/WebAssembly/binaryen/releases`, and compiles Cadova and its dependencies (including the Clipper2 submodule of manifold-swift from GitHub, which the sandbox blocked on the first resolve) for WebAssembly.
3. Either: run the command in their own terminal (recommended: `cd LiddedBin && swift package --allow-network-connections all:443 --allow-writing-to-package-directory generate-customizer`, first run takes several minutes), or allow `download.swift.org` and `github.com` through the Apple Claude Code dashboard (Domains tab). SwiftPM's own plugin sandbox may conflict with the session sandbox; if the command fails here with a sandbox error, the user's own terminal is the fallback.

**Files:**
- Generated: `LiddedBin/Customizer/` (gitignored)

- [ ] **Step 1:** Confirm the toolchain: `ls /Library/Developer/Toolchains | grep 6.4.0` or `swiftly list`; report what exists.
- [ ] **Step 2:** Run (or have the user run) `generate-customizer` in `LiddedBin`. Capture the full output. On success `LiddedBin/Customizer/` contains `index.html`, `model.wasm` and `licenses.html`.
- [ ] **Step 3: Verify without a browser.** `ls -la Customizer`; `model.wasm` size (the guide says about 18 MB, about 5 MB compressed); `curl -sI` against a local server (`python3 -m http.server --directory Customizer 8000` in the background, then curl `http://localhost:8000/` and `/model.wasm`, check status 200 and, for the wasm, that the server sends `application/wasm`); stop the server. Check `licenses.html` mentions Cadova, manifold and the other dependencies.
- [ ] **Step 4: Browser check (the user).** The session cannot see a browser. Give the user this checklist to run at `http://localhost:8000`: the page loads; heading, description and the smkent attribution appear; the Bin tab shows grid, height style, lid and compartment controls; the Lid tab shows no divider controls; dragging grid size updates the preview in a few seconds; Height style changes which height control appears; the three tabs download 3MF files; the Lid and Bin files open in a slicer; the browser console shows no errors and the build time for the default bin. Record the user's results in the ledger.
- [ ] **Step 5:** If a WebAssembly-only failure appears (stack exhaustion, an unsupported Foundation call, a build error in a dependency), reduce the offending range in `LiddedBinLimits` or fix the code, re-run Task 1 to 4 tests, and rebuild. Report any change.
- [ ] **Step 6: Commit** any source changes made here (`Fix customizer build issues`); the generated `Customizer/` folder is not committed.

---

### Task 8: Final review

- [ ] **Step 1:** Both packages: `swift test --skip-update` passes; report counts. `grep -rn "—" LiddedBin GridfinityRebuilt --include=*.swift --include=*.md --include=*.py` finds nothing; `git status` is clean apart from ignored files; the log shows one commit per task.
- [ ] **Step 2:** Final whole-project review on the most capable model, covering: parameter names and ranges versus `lid-bin.scad`'s customizer comments, validation coverage, README accuracy, licensing and attribution, the workflow file, and the list of what the user must verify in a browser.
- [ ] **Step 3:** Report the open decisions (library license confirmation, GitHub repository URL for `source-url`, whether the open assembly should be offered, the quality parameter outcome) and the browser checklist results.

---

## Self-Review

- **Spec coverage:** web customizer with live preview and download (Tasks 4, 7), metadata and attribution (Task 4, 6), WebAssembly limits (Global Constraints, Tasks 3, 7), GitHub Pages publishing with Cadova's action (Task 6), the `Part` choice (Task 4: Bin, Lid, Open assembly), input clamps and height-mode parameters flagged by the previous final review (Tasks 1, 2), build-time limits (Task 3).
- **Placeholder scan:** limit values in Task 1 are explicit starting values that Task 3 replaces by measurement; the `main.swift` skeleton lists the parameter set in prose where the Cadova `switch` forms must be taken from the guide. Both are intentional and bounded.
- **Type consistency:** `LiddedBinLimits`, `validated()`, `HeightStyle`, `LiddedBinInput`, `configuration` are defined in Tasks 1 to 2 and used with the same names in Tasks 3 to 5.
- **Known risks:** (1) the sandbox blocks the WebAssembly toolchain downloads, so Task 7 needs the user; (2) SwiftPM's plugin sandbox may conflict with the session sandbox; (3) a parameter read in the project body appears on every tab, which the Lid tab must avoid; (4) browser behavior cannot be observed from the session; (5) the Clipper2 submodule fetch failed on the first dependency resolve and may block a WebAssembly build until GitHub is reachable; (6) `Project(packageRelative:)` behavior inside the customizer build is untested.
