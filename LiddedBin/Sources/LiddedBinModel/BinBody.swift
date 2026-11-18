import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_base_grid_interior: the base grid shrunk by the wall, raised by the wall thickness.
    func baseGridInterior() -> any Geometry3D {
        baseGrid(sizeOffset: -d.dWall - fit.interiorBaseWallAdjust)
            .translated(z: d.dWall)
    }

    /// gf_base_grid. The clipping box sits inside `pattern_linear` in OpenSCAD, so it moves
    /// with each cell; that is kept here.
    func baseGrid(sizeOffset: Double = 0) -> any Geometry3D {
        patternLinear(
            x: configuration.gridX, y: configuration.gridY,
            spacingX: d.lGrid, spacingY: d.lGrid,
            d.blockBaseSolid(nx: 1, ny: 1, length: d.lGrid, offset: sizeOffset)
                .intersecting {
                    Rectangle([gridX * d.lGrid, gridY * d.lGrid])
                        .aligned(at: .center)
                        .extruded(height: d.hBase + d.hBot / 2)
                }
        )
    }

    /// gf_cut_pocket_interior
    private func pocketInterior(_ size: Vector2D) -> any Geometry3D {
        Rectangle(size)
            .aligned(at: .center)
            .extruded(height: innerHeight - fit.thickness - fit.vFitTolerance - fit.vPosTolerance + 0.001)
            .translated(z: -storageHeight - d.hBase + d.dWall)
    }

    /// gf_cut_pocket: one compartment at (x, y) spanning w by h grid units.
    func pocket(x: Double, y: Double, w: Double, h: Double) -> any Geometry3D {
        bin.placed(x: x, y: y, w: w, h: h, pocketInterior(pocketSize(xUnits: w, yUnits: h)))
    }

    /// gf_cut_pockets (the custom pattern is not supported). Nil when no pockets are produced.
    func pockets() -> (any Geometry3D)? {
        let c = configuration
        var cuts: [any Geometry3D] = []
        switch c.compartmentPattern {
        case .grid:
            guard c.divX > 0, c.divY > 0 else { return nil }
            let divX = Double(c.divX), divY = Double(c.divY)
            for x in 1...c.divX {
                for y in 1...c.divY {
                    cuts.append(pocket(
                        x: Double(x - 1) * gridX / divX, y: Double(y - 1) * gridY / divY,
                        w: gridX / divX, h: gridY / divY
                    ))
                }
            }
        case .multiSize:
            // With divx = 0 OpenSCAD's sizes become inf and nan; treat that as no pockets.
            guard c.divX > 0 else { return nil }
            let divX = Double(c.divX), divY = Double(c.divY)
            let w = gridX / divX, h = gridY / divY
            let offDivX = (divX / 2).rounded(.up)
            let remGridX = w * (divX - offDivX)
            let offGridX = gridX - remGridX
            // Clamped to lid-bin.scad's customizer range for div_multiple, [1:.5:5]. This keeps
            // in-range results unchanged and stops a value of 0 or less from making remDivX and
            // remDivY infinite, which would make the stride loops below never end.
            let multiple = min(max(c.divMultiple, 1), 5)
            let remDivX = max(1, (remGridX / (w * multiple)).rounded(.down))
            let remDivY = max(1, (divY / multiple).rounded(.down))
            for x in stride(from: 1.0, through: offDivX, by: 1) {
                for y in stride(from: 1.0, through: divY, by: 1) {
                    cuts.append(pocket(x: (x - 1) * w, y: (y - 1) * h, w: w, h: h))
                }
            }
            for x in stride(from: 1.0, through: remDivX, by: 1) {
                for y in stride(from: 1.0, through: remDivY, by: 1) {
                    cuts.append(pocket(
                        x: offGridX + (x - 1) * remGridX / remDivX,
                        y: (y - 1) * gridY / remDivY,
                        w: remGridX / remDivX, h: gridY / remDivY
                    ))
                }
            }
        }
        return cuts.isEmpty ? nil : Union(cuts)
    }

    /// gf_bin_solid. The interior cut is `intersection() { rounded_rect; children(); }` in
    /// OpenSCAD. With no pockets, `children()` is empty, the intersection is empty and nothing
    /// is cut, so `pockets == nil` leaves the floor block solid.
    func binSolid(pockets: (any Geometry3D)?) -> any Geometry3D {
        Union {
            binWall()
            binFloor(pockets: pockets)
            binFeet()
        }
    }

    /// First part of gf_bin_solid: the wall with lid lip and tabs, minus the lip mask and grips.
    func binWall() -> any Geometry3D {
        Union {
            d.blockWall(gridX: gridX, gridY: gridY, profile: lidLipWallProfile(lid: false),
                        cornerSegments: configuration.cornerSegments)
            lidTabs()
        }
        .subtracting {
            lidLipMask().translated(x: -fit.lipFitTolerance, z: -fit.lipFitTolerance)
            if let grips = lipGripMasks() { grips }
        }
    }

    /// Second part of gf_bin_solid: the floor block with the interior base grid, minus the
    /// pockets clipped to the interior.
    func binFloor(pockets: (any Geometry3D)?) -> any Geometry3D {
        let override = configuration.internalHeightOverride
        let aa = -(0.5 + d.dWall * 1.25 + fit.separatorWallThickness / 4)
        let bottomHeight = (override == 0 ? storageHeight - 0.1 : override)
            - fit.thickness - fit.vFitTolerance - fit.vPosTolerance

        return Union {
            d.blockBottom(height: bottomHeight, gridX: gridX, gridY: gridY)
            baseGridInterior()
        }
        .subtracting {
            if let pockets {
                roundedRect(height: innerHeight, addSize: aa, radius: d.rBase * 2)
                    .translated(z: d.dWall)
                    .intersecting { pockets }
            }
        }
    }

    /// Third part of gf_bin_solid: the base feet. With partial_raised the interior is limited
    /// to the raised slab; otherwise the OpenSCAD intersection holds only the interior (the
    /// false `if` adds no operand).
    func binFeet() -> any Geometry3D {
        let interior = baseGridInterior()
        let interiorLimit: any Geometry3D = configuration.interiorStyle == .partialRaised
            ? Rectangle([d.lGrid * gridX, d.lGrid * gridY])
                .aligned(at: .center)
                .extruded(height: d.hBase - d.rC2)
                .translated(z: d.hBot + d.hBase - d.rC2 + 0.1)
                .intersecting { interior }
            : interior
        return roundedRect(height: d.hBase + d.hBot / 2 * 10, addSize: -0.5)
            .translated(z: -1)
            .intersecting {
                Union {
                    baseGrid()
                    roundedRect(height: d.hBot / 2, addSize: -0.5).translated(z: d.hBase)
                }
                .subtracting { interiorLimit }
            }
    }
}
