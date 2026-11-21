import Cadova
import Foundation

extension Dimensions {
    /// The number of feet per grid cell along one axis in `gridfinityBase`, the reciprocal of
    /// OpenSCAD's `dbnx`. With `division` 0 it is the first `i` in 1 to 5 for which `grid * i`
    /// is within 0.001 of an integer, else 1; otherwise it is `division` rounded.
    public func baseSubdivisions(_ grid: Double, division: Double = 0) -> Double {
        if division != 0 { return division.rounded() }
        let first = (1...5).first { i in
            let f = abs(grid * Double(i)).truncatingRemainder(dividingBy: 1)
            return f < 0.001 || f > 0.999
        }
        return Double(first ?? 1)
    }

    /// Ports OpenSCAD `gridfinityBase`: a `gx` by `gy` grid of feet with holes.
    ///
    /// Each grid cell is split into `baseSubdivisions` feet per axis (so a 1.5 cell grid uses
    /// half-cell feet), and `divisionX` / `divisionY` override that count. With `finalCut` the
    /// feet are clipped to the bin outline and a separate block `hBot / 1.5` tall is added on
    /// top at `hBase`. With `onlyCorners` the feet have no holes of their own and four holes
    /// of `styleHole` go at the outer corners of the whole grid.
    public func gridfinityBase(
        gridX gx: Double, gridY gy: Double, length: Double? = nil,
        divisionX dx: Double = 0, divisionY dy: Double = 0,
        styleHole: Int, offset: Double = 0, finalCut: Bool = true, onlyCorners: Bool = false
    ) -> any Geometry3D {
        let l = length ?? lGrid
        let dbnx = 1 / baseSubdivisions(gx, division: dx)
        let dbny = 1 / baseSubdivisions(gy, division: dy)
        let xx = gx * l - 0.5
        let yy = gy * l - 0.5

        let feet: any Geometry3D = if onlyCorners {
            patternLinear(
                x: gx / dbnx, y: gy / dbny, spacingX: dbnx * l, spacingY: dbny * l,
                blockBase(nx: dbnx, ny: dbny, length: l, styleHole: 0, offset: offset)
            )
            .subtracting {
                patternLinear(
                    x: 2, y: 2,
                    spacingX: (gx - 1) * lGrid + dHole, spacingY: (gy - 1) * lGrid + dHole,
                    blockBaseHole(style: styleHole, offset: offset)
                )
            }
        } else {
            patternLinear(
                x: gx / dbnx, y: gy / dbny, spacingX: dbnx * l, spacingY: dbny * l,
                blockBase(nx: dbnx, ny: dbny, length: l, styleHole: styleHole, offset: offset)
            )
        }

        return Union {
            if finalCut {
                roundedRectangle(length: xx + 0.002, width: yy + 0.002, height: hBot / 1.5, radius: rFo1 / 2 + 0.001)
                    .translated(z: hBase)
                feet.intersecting {
                    roundedRectangle(
                        length: xx + 0.005, width: yy + 0.005, height: hBase + hBot / 2 * 10, radius: rFo1 / 2 + 0.001
                    )
                    .translated(z: -1)
                }
            } else {
                feet
            }
        }
    }
}
