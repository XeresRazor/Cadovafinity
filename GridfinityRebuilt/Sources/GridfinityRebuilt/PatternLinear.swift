import Cadova

/// `pattern_linear`: a `x` by `y` grid of copies of `geometry`, centered on the origin.
///
/// Port of the OpenSCAD module of the same name. `spacingY` defaults to `spacingX`.
public func patternLinear(
    x: Int, y: Int,
    spacingX sx: Double,
    spacingY sy: Double? = nil,
    _ geometry: any Geometry3D
) -> any Geometry3D {
    let yy = (sy ?? sx) <= 0 ? sx : (sy ?? sx)
    return Union {
        for i in 0..<max(x, 0) {
            for j in 0..<max(y, 0) {
                geometry.translated(x: Double(i) * sx, y: Double(j) * yy)
            }
        }
    }
    .translated(x: -Double(x - 1) * sx / 2, y: -Double(y - 1) * yy / 2)
}

/// `pattern_linear` with fractional counts: `ceil(x)` by `ceil(y)` copies, centered with the
/// raw counts as OpenSCAD does (`-(x-1)*sx/2`), so a fractional count is not centered on the
/// copies. A count of 0 or less gives no copies (OpenSCAD's reversed range `[1:0]` is empty).
public func patternLinear(
    x: Double, y: Double,
    spacingX sx: Double,
    spacingY sy: Double? = nil,
    _ geometry: any Geometry3D
) -> any Geometry3D {
    let yy = (sy ?? sx) <= 0 ? sx : (sy ?? sx)
    let nx = max(Int(x.rounded(.up)), 0), ny = max(Int(y.rounded(.up)), 0)
    return Union {
        for i in 0..<nx {
            for j in 0..<ny {
                geometry.translated(x: Double(i) * sx, y: Double(j) * yy)
            }
        }
    }
    .translated(x: -(x - 1) * sx / 2, y: -(y - 1) * yy / 2)
}
