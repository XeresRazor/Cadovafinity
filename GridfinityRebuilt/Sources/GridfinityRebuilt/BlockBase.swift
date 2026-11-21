import Cadova
import Foundation

extension Dimensions {
    /// Ports OpenSCAD `block_base_solid`: one grid cell's base, narrowing toward the bottom.
    /// `nx` and `ny` are cell counts along X and Y, `length` is the grid pitch and `offset`
    /// the outward offset, all in mm. Centered in XY, from z = 0 up to `hBase`.
    public func blockBaseSolid(
        nx: Double = 1,
        ny: Double = 1,
        length: Double? = nil,
        offset o: Double = 0
    ) -> any Geometry3D {
        let l = length ?? lGrid
        let xx = nx * l - 0.05
        let yy = ny * l - 0.05
        let oo = (o / 2) * (2.0.squareRoot() - 1)

        return Union {
            // Chamfered lower section
            Union {
                roundedRectangle(
                    length: xx - 2 * rC2 - 2 * rC1 + o,
                    width: yy - 2 * rC2 - 2 * rC1 + o,
                    height: hBase + oo,
                    radius: rFo3 / 2
                )
                roundedRectangle(
                    length: xx - 2 * rC2 + o,
                    width: yy - 2 * rC2 + o,
                    height: hBase - rC1 + oo,
                    radius: rFo2 / 2
                )
            }
            .convexHull()

            // Upper section, blending out to the full cell width
            Union {
                roundedRectangle(
                    length: xx - 2 * rC2 + o,
                    width: yy - 2 * rC2 + o,
                    height: rC2,
                    radius: rFo2 / 2
                )
                roundedRectangle(
                    length: xx + o,
                    width: yy + o,
                    height: hBot / 2 + abs(10 * o),
                    radius: rFo1 / 2
                )
                .flipped(along: .z)
            }
            .convexHull()
            .translated(z: oo)
        }
        .flipped(along: .z)
        .translated(z: hBase)
    }
}

extension Dimensions {
    /// Ports OpenSCAD `block_base`: one foot of `nx` by `ny` grid cells (`blockBaseSolid`) with
    /// four holes, one per corner, at `(l / 2 - dHoleFromSide, l / 2 - dHoleFromSide)` rotated a
    /// quarter turn at a time. Style 0 has no holes, styles 1 to 3 use `blockBaseHole` and style 4
    /// uses `refinedHole` lifted by `2 * hSlit`. The hole positions use the grid pitch `length`,
    /// not the foot size.
    public func blockBase(
        nx: Double = 1,
        ny: Double = 1,
        length: Double? = nil,
        styleHole: Int,
        offset o: Double = 0
    ) -> any Geometry3D {
        let l = length ?? lGrid
        let p = l / 2 - dHoleFromSide
        return blockBaseSolid(nx: nx, ny: ny, length: l, offset: o)
            .subtracting {
                if styleHole > 0 {
                    patternCircular(
                        count: 4,
                        styleHole == 4
                            ? refinedHole().translated(x: p, y: p, z: hSlit * 2)
                            : blockBaseHole(style: styleHole, offset: o).translated(x: p, y: p)
                    )
                }
            }
    }
}
