import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    // The slot roof.
    //
    // Distances below are measured inward from the outer wall face (`a` for the slot face, `f`
    // for the lip's inner face) and heights from the plate top (`dh - vPos` in the profile). The
    // groove polygon's roof starts at the slot face (`a = wallThickness`, 1.2) at the plate top
    // and rises inward with slope `s`. It ends where it meets the inside of the wall, which comes
    // from `profile_wall`'s lip: the base profile, offset by `dClear`, cut from the wall.
    // - The lip's vertical inner face is at `f = rC2 - 2 * dClear` (1.9, y = 39.85 for a 2x2 bin),
    //   from `kneeRise` up to the inner top chamfer at `vPos + hBase - rC2 + dClear * (1 - sqrt 2)`
    //   (2.696 above the plate top, z = 23.5).
    // - Below it a 45 degree overhang (the base's `rC1` chamfer, offset) runs inward and down. On
    //   it, run + rise = `rC2 + rC1 - dClear * (1 + sqrt 2) + vPos - a` (1.596), and it meets the
    //   vertical face at `kneeRise = vPos + rC1 + dClear * (1 - sqrt 2)` (0.896).
    // The original 45 degree roof ends on that overhang: run = rise = 1.596 / 2 = 0.798 (the tip
    // at y = 39.75, z = 21.6). A roof steeper than `kneeRise / faceRun` (1.28) ends on the
    // vertical face instead, so its run is `faceRun = f - a = 0.7` and its rise is `0.7 * s`.
    //
    // `fit.chamfer` is the roof's rise. 0.8 (the original's 0.798, rounded) is the original
    // polygon with s = 1 exactly. From the knee rise up, s = rise / 0.7, which puts the tip at
    // exactly that height on the vertical face. In between, s is interpolated linearly, which
    // keeps the rise within 0.003 mm of the setting. The roof tip stays below the inner top
    // chamfer for rises up to 2.696, above the 2.0 maximum of `LiddedBinLimits.lidChamfer`.

    /// The horizontal run of a roof that ends on the lip's vertical inner face (0.7).
    var roofFaceRun: Double { d.rC2 - 2 * d.dClear - fit.wallThickness }

    /// The rise at which the roof meets the bottom of the lip's vertical inner face (0.896).
    var roofKneeRise: Double { fit.vPosTolerance + d.rC1 + d.dClear * (1 - 2.0.squareRoot()) }

    /// The slope (rise over run) of the slot roof for `fit.chamfer`. 1 for the original rise.
    var roofSlope: Double {
        let rise = fit.chamfer, original = LidFit.originalChamfer
        let run = roofFaceRun, knee = roofKneeRise
        guard rise > original, run > 0 else { return 1 }
        if rise >= knee || knee <= original { return max(1, rise / run) }
        return 1 + (rise - original) * (knee / run - 1) / (knee - original)
    }

    /// How far the lid's groove roof is lowered so that it stays parallel to the bin's roof at the
    /// original perpendicular distance. The lid's polygon starts `wallThickness - hFitTolerance`
    /// (0.1) further out than the bin's. At 45 degrees that is 0.1 / sqrt 2 = 0.071 across the
    /// roof (the tongue chamfer's gap is then `lipClearance - 0.071`, 0.229 for 0.30). A steeper
    /// roof would turn the same horizontal step into a larger perpendicular one and narrow the
    /// gap, so the lid's roof drops by `0.1 * (s - sqrt((1 + s^2) / 2))` for slope `s`. That is
    /// 0 for s = 1, so the original lid is unchanged.
    var lidRoofDrop: Double {
        let s = roofSlope
        return (fit.wallThickness - fit.hFitTolerance) * (s - ((1 + s * s) / 2).squareRoot())
    }

    /// gf_profile_wall_lid_lip: the wall profile with the groove the lid slides in. The roof
    /// slope follows `fit.chamfer` (see `roofSlope`).
    func lidLipWallProfile(lid: Bool) -> any Geometry2D {
        let dh = storageHeight
        let s = roofSlope
        let roofBase = fit.thickness + fit.vFitTolerance - (lid ? lidRoofDrop : 0)
        return d.wallProfile(height: dh)
            .subtracting {
                Polygon([
                    [0, 0],
                    [0, roofBase],
                    [d.dWall2, roofBase + d.dWall2 * s],
                    [d.dWall2, 0],
                ])
                .translated(
                    x: lid ? fit.hFitTolerance : fit.wallThickness,
                    y: dh - fit.thickness - fit.vFitTolerance - fit.vPosTolerance
                )
                .flipped(along: .x)
                .translated(x: d.rBase)
            }
    }

    /// gf_bin_lid_lip_mask: the slab above the lid groove, shifted toward the lid's open side.
    func lidLipMask() -> any Geometry3D {
        let p = lidPosition(adjust: -(d.rBase + 0.5))
        return Rectangle([d.lGrid * gridX, d.lGrid * gridY])
            .aligned(at: .center)
            .extruded(height: d.hLip * 10)
            .translated(x: p.x, y: p.y, z: storageHeight + d.hBase - fit.thickness - fit.vPosTolerance)
    }

    /// gf_bin_rounded_rect. `radius` is OpenSCAD's third argument `r` (default `r_fo1`).
    func roundedRect(height: Double, addSize: Double = 0, radius: Double? = nil) -> any Geometry3D {
        roundedRectangle(
            length: gridX * d.lGrid + addSize + 0.005,
            width: gridY * d.lGrid + addSize + 0.005,
            height: height,
            radius: (radius ?? d.rFo1) / 2 + 0.001
        )
    }

    /// gf_bin_lid_grip_mask_shape (2D)
    private func gripShape() -> any Geometry2D {
        let gripW = d.lGrid / 2 - d.hLip * 2 - 2
        let radius = 3.0
        return Union {
            Rectangle([gripW, d.hLip * 10])
            Rectangle([gripW * 5, d.hLip * 9]).translated(x: -gripW * 2, y: d.hLip * 0.75)
        }
        .offset(amount: -radius, style: .round)
        .offset(amount: 2 * radius, style: .round)
        .offset(amount: -radius, style: .round)
        .intersecting {
            Rectangle([gripW + radius * 2, d.hLip]).translated(x: -radius)
        }
        .translated(x: -(gripW - d.lGrid / 2) / 2)
    }

    /// gf_bin_lid_grip_mask_set(num_grid):
    /// rotate([90, 0, 90]) translate([0, 0, l_grid * num_grid / 2]) linear_extrude(l_grid / 2, center=true)
    private func gripSet(numGrid: Int) -> any Geometry3D {
        gripShape()
            .extruded(height: d.lGrid / 2)
            .translated(z: -d.lGrid / 4)
            .translated(z: d.lGrid * Double(numGrid) / 2)
            .rotated(x: 90°, y: 0°, z: 90°)
    }

    /// gf_bin_lid_grip_mask
    private func gripMask() -> any Geometry3D {
        let gx = configuration.gridX, gy = configuration.gridY
        let grips = configuration.lipGrips
        return Union {
            if grips == .x || grips == .xy {
                patternLinear(x: 1, y: gy, spacingX: d.lGrid * gridX, spacingY: d.lGrid, gripSet(numGrid: gx))
            }
            if grips == .y || grips == .xy {
                patternLinear(x: gx, y: 1, spacingX: d.lGrid, spacingY: d.lGrid * gridY, gripSet(numGrid: gy).rotated(z: 90°))
            }
        }
        .translated(z: storageHeight + d.hBase + d.hLip * 0.25)
    }

    /// gf_bin_lid_grip_masks: the mask and the mask rotated 180 degrees. Nil when grips are off.
    func lipGripMasks() -> (any Geometry3D)? {
        guard configuration.lipGrips != .none else { return nil }
        return Union {
            gripMask()
            gripMask().rotated(z: 180°)
        }
    }

    /// gf_bin_lid_tabs: the two small tabs that hold the lid closed.
    func lidTabs(adjust: Bool = false) -> any Geometry3D {
        let adj = adjust ? -fit.hFitTolerance * 1.5 + fit.wallThickness : 0
        let cr = 0.6
        let m = lidDirection
        let tabPosX = m.x * (-(d.lGrid * gridX - 0.5) / 2 + d.rBase + cr)
        let tabPosY = m.y * (-(d.lGrid * gridY - 0.5) / 2 + d.rBase + cr)
        let sepX = abs(m.y) * (gridX * d.lGrid / 2 - 0.5 / 2 - fit.wallThickness + adj)
        let sepY = abs(m.x) * (gridY * d.lGrid / 2 - 0.5 / 2 - fit.wallThickness + adj)

        let profile = Union {
            Circle(radius: cr)
            Rectangle(cr * 8).aligned(at: .center).translated(y: cr * 4)
        }
        .offset(amount: cr * 0.5, style: .round)
        .offset(amount: -(cr * 0.5), style: .round)
        .intersecting {
            Rectangle([cr * 3, cr * 2]).aligned(at: .center)
        }

        let tab = profile
            .extruded(height: fit.lipFitTolerance * 2 + fit.thickness + 2)
            .rotated(z: m.x != 0 ? 0° : 270°)
            .translated(x: sepX, y: sepY, z: -fit.vFitTolerance - fit.vPosTolerance)

        // OpenSCAD loops over mirror([0, ml]) for ml in [0, 1]; mirror([0, 0]) is the identity.
        return Union {
            tab
            tab.flipped(along: m.x != 0 ? .y : .x)
        }
        .translated(
            x: tabPosX, y: tabPosY,
            z: storageHeight + d.hBase - fit.thickness - fit.lipFitTolerance / 2 - 0.001
        )
    }
}
