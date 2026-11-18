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
