# GridfinityCustomizers

Customizers for the standard Gridfinity components, written in Swift with
[Cadova](https://github.com/tomasf/Cadova). Each component is meant to be its own web customizer
page. The baseplate is first; the bin, the lite bin and the spiral vase bin are planned.

Today the package is a scaffold: the `GridfinityModels` library holds only a version constant, and
the `gridfinity-baseplate` executable is a stub that builds a 1 mm cube named "Baseplate". The
baseplate model itself is not written yet.

## License

MIT, see `LICENSE`. The package is a Swift port of the customizers in
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad), and
`LICENSE` reproduces the licenses of that project and of Gridfinity, on which it is based.

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

`swift run gridfinity-baseplate` writes `Models/Baseplate.3mf`.

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
