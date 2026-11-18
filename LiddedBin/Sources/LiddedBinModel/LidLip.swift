import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_profile_wall_lid_lip: the wall profile with the groove the lid slides in.
    func lidLipWallProfile(lid: Bool) -> any Geometry2D {
        let dh = storageHeight
        return d.wallProfile(height: dh)
            .subtracting {
                Polygon([
                    [0, 0],
                    [0, fit.thickness + fit.vFitTolerance],
                    [d.dWall2, fit.thickness + fit.vFitTolerance + d.dWall2],
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
