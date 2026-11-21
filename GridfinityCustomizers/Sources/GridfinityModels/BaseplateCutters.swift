import Cadova
import GridfinityRebuilt

/// The cutters that shape a baseplate: weight pockets, the skeleton outline, the screw hole
/// cutters, the per-cell hole pattern and the screw-together channels.
///
/// Port of gridfinity-rebuilt-baseplate.scad lines 136 to 209.
struct BaseplateCutters {
    let d: Dimensions
    let b: BaseplateDimensions

    /// `cutter_weight`: a square pocket and four slot-and-round pockets.
    func weight() -> any Geometry3D {
        Union {
            Rectangle(b.bpCutSize).aligned(at: .center)
                .extruded(height: b.bpCutDepth * 2).aligned(at: .centerZ)
            patternCircular(
                count: 4,
                Union {
                    Rectangle([b.bpRcutWidth, b.bpRcutLength]).aligned(at: .center)
                    Circle(diameter: b.bpRcutWidth).translated(y: b.bpRcutLength / 2)
                }
                .extruded(height: b.bpRcutDepth * 2).aligned(at: .centerZ)
                .translated(y: 10)
            )
        }
    }

    /// `hole_pattern`: four copies of `children`, one at each hole position of a grid cell.
    func holePattern(_ children: any Geometry3D) -> any Geometry3D {
        let p = d.lGrid / 2 - d.dHoleFromSide
        return patternCircular(count: 4, children.translated(x: p, y: p))
    }

    /// `cutter_countersink`: the screw hole with a 45 degree countersink opening at z = 0.
    func countersink() -> any Geometry3D {
        let r = d.rHole1 + d.dClear
        return Union {
            Cylinder(radius: r, height: 100 * d.hBase).aligned(at: .centerZ)
            Union {
                Cylinder(radius: r, height: b.dCs + 10)
                Cylinder(radius: r + b.dCs, height: b.dCs + 10).translated(z: b.dCs)
            }
            .convexHull()
            .flipped(along: .z)
            .translated(z: b.dCs)
        }
    }

    /// `cutter_counterbore`: the screw hole with a counterbore bridged by printable slits.
    func counterbore() -> any Geometry3D {
        Union {
            Cylinder(radius: d.rHole1 + d.dClear, height: 100 * d.hBase).aligned(at: .centerZ)
            Cylinder(radius: b.rCb, height: 2 * (b.hCb + 0.2)).aligned(at: .centerZ)
                .subtracting {
                    copyMirror(
                        Box([b.rCb * 3, b.rCb * 3, 10])
                            .translated(x: -1.5 * b.rCb, y: d.rHole1 + d.dClear + 0.1, z: b.hCb - d.hSlit),
                        along: .y
                    )
                }
        }
    }

    /// `profile_skeleton`: the plate floor outline with bosses around the holes, in 2D.
    ///
    /// OpenSCAD builds it as `minkowski(square - 4 bosses, circle(r_skel))`, each boss being
    /// `minkowski(square(l), circle(r_hole2 + r_skel + 2))` at a hole position. A round offset
    /// is not the same set: the minkowski with a polygonal circle moves the boss arc's edges by
    /// the circle's apothem and places corner arcs on the circle's own vertex angles, while a
    /// round offset moves every edge by the full radius and starts each arc at the edge
    /// normal (0.40 mm^3 apart over a 5 mm extrusion). `SkeletonProfile` builds the minkowski
    /// sum itself, from the same polygons OpenSCAD uses.
    func skeletonProfile() -> any Geometry2D {
        let l = d.lGrid - 2 * d.rC2 - 2 * d.rC1
        return SkeletonProfile(
            halfSide: (l - 2 * b.rSkel + 2 * d.dClear) / 2,
            holePosition: d.lGrid / 2 - d.dHoleFromSide,
            bossRadius: d.rHole2 + b.rSkel + 2,
            skeletonRadius: b.rSkel
        )
    }

    /// `cutter_screw_together`: the screw channels across the plate edges of a `gridX` by
    /// `gridY` baseplate whose floor is `offset` thick.
    func screwTogether(
        gridX gx: Int, gridY gy: Int, offset off: Double,
        screwDiameter: Double, screwHeadDiameter: Double, screwSpacing: Double, screwCount: Int
    ) -> any Geometry3D {
        func screw(_ a: Int, _ bCount: Int) -> any Geometry3D {
            let channel = Cylinder(diameter: screwDiameter, height: d.lGrid / 2)
                .aligned(at: .centerZ)
                .rotated(y: 90°)
            let row = patternLinear(
                x: 1, y: bCount, spacingX: 1, spacingY: d.lGrid,
                patternLinear(x: 1, y: screwCount, spacingX: 1, spacingY: screwHeadDiameter + screwSpacing, channel)
            )
            return copyMirror(row.translated(x: Double(a) * d.lGrid / 2, z: -off / 2), along: .x)
        }
        let alongX = screw(gx, gy)
        let alongY = screw(gy, gx).rotated(z: 90°)
        return Union {
            alongX
            alongY
        }
    }
}

/// The minkowski sum `(S - B) + D` of `profile_skeleton`, built exactly.
///
/// `S` is the centered square of half side `halfSide`. `B` is four bosses, the first the
/// square from `(holePosition, holePosition)` outward (side `l`, reaching past `S`) grown by an
/// `nB`-gon of radius `bossRadius`, the others its copies turned by multiples of 90 degrees.
/// `D` is the `nS`-gon of radius `skeletonRadius`. Both polygons have a vertex at angle 0, as
/// OpenSCAD's `circle` does.
///
/// Inside `S`, the bosses leave a plus-shaped region: a band `|y| <= q` across the full width,
/// a band `|x| <= q` across the full height (`q = holePosition - bossRadius`), and in each
/// quadrant a fillet between the bands and the boss arc. The minkowski sum distributes over a
/// union, and the sum of a convex polygon with `D` is the hull of `D` placed at its vertices,
/// so the result is the union of those hulls for the two bands and for the triangles that fan
/// each fillet from its inner corner. The fillet's arc runs from 180 to 270 degrees on the boss
/// polygon, so both segment counts are rounded up to a multiple of four to keep vertices there.
private struct SkeletonProfile: Geometry2D {
    let halfSide: Double
    let holePosition: Double
    let bossRadius: Double
    let skeletonRadius: Double
    @Environment(\.segmentation) private var segmentation

    var body: any Geometry2D {
        let h = halfSide, p = holePosition
        let q = p - bossRadius
        precondition(q > 0 && p < h, "the bosses must cut the skeleton square into a plus shape")

        let nS = Self.multipleOfFour(segmentation.segmentCount(circleRadius: skeletonRadius))
        let nB = Self.multipleOfFour(segmentation.segmentCount(circleRadius: bossRadius))
        let disk = Self.polygonPoints(radius: skeletonRadius, count: nS)

        // The fillet fan in the first quadrant: the inner corner and the boss arc from 180 to
        // 270 degrees around the hole position.
        let corner = Vector2D(q, q)
        let boss = Self.polygonPoints(radius: bossRadius, count: nB)
        let arc = (nB / 2...3 * nB / 4).map { k in Vector2D(p, p) + boss[k % nB] }
        var pieces: [[Vector2D]] = [
            [[-h, -q], [h, -q], [h, q], [-h, q]],
            [[-q, -h], [q, -h], [q, h], [-q, h]],
        ]
        for quarter in 1...4 {
            // pattern_circular turns the bosses by quarter * 90 degrees; a quarter turn of a
            // point is exact as a coordinate swap.
            func turned(_ v: Vector2D) -> Vector2D {
                var v = v
                for _ in 0..<(quarter % 4) { v = Vector2D(-v.y, v.x) }
                return v
            }
            for k in 0..<(arc.count - 1) {
                pieces.append([turned(corner), turned(arc[k]), turned(arc[k + 1])])
            }
        }
        let convexPieces = pieces
        return Union {
            for piece in convexPieces {
                Union {
                    for v in piece {
                        Polygon(disk).translated(v)
                    }
                }
                .convexHull()
            }
        }
    }

    /// The vertices of OpenSCAD's `circle(r, $fn = count)`, counterclockwise from angle 0.
    static func polygonPoints(radius: Double, count: Int) -> [Vector2D] {
        (0..<count).map { k in
            let a = Angle(degrees: 360 * Double(k) / Double(count))
            return Vector2D(radius * cos(a), radius * sin(a))
        }
    }

    static func multipleOfFour(_ n: Int) -> Int { max(4, (n + 3) / 4 * 4) }
}
