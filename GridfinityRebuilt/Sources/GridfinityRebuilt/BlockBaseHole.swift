import Cadova

extension Dimensions {
    /// `block_base_hole`: magnet (style 1), magnet and screw (2), magnet with a printable slit and screw (3).
    public func blockBaseHole(style: Int, offset o: Double = 0) -> any Geometry3D {
        let r1 = rHole1 - o / 2
        let r2 = rHole2 - o / 2
        let magnetHeight = 2 * (hHole - o + (style == 3 ? hSlit : 0))
        let magnet = Cylinder(radius: r2, height: magnetHeight).aligned(at: .centerZ)
            .subtracting {
                if style == 3 {
                    copyMirror(
                        Box([r2 * 3, r2 * 3, 10]).translated(x: -1.5 * r2, y: r1 + 0.1, z: hHole - o),
                        along: .y
                    )
                }
            }
        return Union {
            magnet
            if style > 1 {
                Cylinder(radius: r1, height: 2 * hBase - o).aligned(at: .centerZ)
            }
        }
    }

    /// `refined_hole`: the squeezed magnet hole with a poke-through slot (Printables @grizzie17).
    public func refinedHole() -> any Geometry3D {
        let r = rHole2 - 0.32
        let m = 2.0, mh = m - 0.1
        let ptl = hSlit * 3, pth = mh + ptl, ptr = 2.5
        return Union {
            Union {
                Box([1, r * 2, mh]).translated(x: 10, y: -r)
                Cylinder(radius: r, height: 1.9)
            }.convexHull()
            Union {
                Box([1, ptr, pth]).translated(x: -9 + 5.60, y: -ptr / 2, z: -ptl)
                Cylinder(diameter: ptr, height: pth).translated(x: -12.53 + 5.60, z: -ptl)
            }.convexHull()
        }
    }
}
