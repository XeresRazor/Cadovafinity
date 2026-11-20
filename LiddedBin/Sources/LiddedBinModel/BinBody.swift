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

    /// gf_cut_pockets (the custom pattern is not supported). Nil when no pockets are produced;
    /// `binSolid` then cuts the whole interior (see there).
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
    /// OpenSCAD. With no pockets, `children()` is empty there, the intersection is empty and
    /// nothing is cut, so the original bin comes out solid.
    ///
    /// Deliberate deviation from OpenSCAD: `pockets == nil` cuts the whole interior (the
    /// `interiorCut` rounded rectangle with its own corners), giving a hollow bin with one open
    /// compartment. It is not the same bin as a single compartment (one pocket): the pocket stops
    /// at the 1.6 mm wall line, while `interiorCut` reaches about 0.45 mm further, so the walls of
    /// the open bin are thinner. The solid result is an artifact of the empty-children quirk, not a
    /// design intent.
    func binSolid(pockets: (any Geometry3D)?) -> any Geometry3D {
        Union {
            binWall()
            binFloor(pockets: pockets)
            binFeet()
        }
    }

    /// The dividers: the material between the compartments that stands above the pocket floor,
    /// for the "Dividers" part. That is the bin inside the strips between the pockets (the plan
    /// view of the rectangle the pockets tile, minus the pockets), within the interior footprint
    /// from the pocket floor up (`dividerRegion`), minus the wall with its lip and detent bumps.
    /// Everything else is the bin body: the wall, the floor under the pockets, the feet and the
    /// ridges between them where they stand inside a pocket, and the ring between the pockets and
    /// the wall. Nil for a bin without pockets, which has no dividers.
    ///
    /// The strips are cut in 2D, where the outer faces of the outer pockets and the edge of their
    /// hull cancel cleanly; a 3D hull minus the pockets leaves zero-thickness sheets there, which
    /// spoil the mesh of the body. The strip faces still meet coincident faces inside the floor
    /// (where the interior fill meets the feet), which leave a few zero-volume shells in both
    /// parts; `droppingEmptyShells` removes them.
    func binDividers(pockets: (any Geometry3D)?) -> (any Geometry3D)? {
        guard let pockets else { return nil }
        let outline = pockets.projected()
        let strips = outline.convexHull()
            .subtracting { outline }
            .extruded(height: innerHeight + d.hLip * 3)
        return droppingEmptyShells(
            binSolid(pockets: pockets)
                .intersecting { dividerRegion() }
                .intersecting { strips }
                .subtracting { binWall() }
        )
    }

    /// The volume in mm^3 under which a disconnected shell counts as empty. The shells left by
    /// coincident faces measure about 1e-15 mm^3; the smallest real piece of a bin is many orders
    /// larger.
    static let emptyShellVolume = 1e-6

    /// The geometry without its disconnected shells of (near) zero volume.
    func droppingEmptyShells(_ geometry: any Geometry3D) -> any Geometry3D {
        geometry.evaluating { g, evaluator in
            var kept: [any Geometry3D] = []
            for component in await evaluator.components(of: g) {
                if await evaluator.measurements(of: component).volume > Self.emptyShellVolume {
                    kept.append(component)
                }
            }
            return Union(kept)
        }
    }

    /// The interior footprint from the pocket floor (z = dWall) to the top of the bin, past the
    /// top of the dividers (`floorTop`).
    func dividerRegion() -> any Geometry3D {
        interiorFootprint(height: innerHeight).translated(z: d.dWall)
    }

    /// The bin without its dividers, for the "Bin body" part. Together with `binDividers` it is
    /// exactly `binSolid(pockets:)`: the two do not overlap and leave no gap.
    func binBody(pockets: (any Geometry3D)?) -> any Geometry3D {
        guard let dividers = binDividers(pockets: pockets) else { return binSolid(pockets: pockets) }
        return droppingEmptyShells(binSolid(pockets: pockets).subtracting { dividers })
    }

    /// The height of the floor block in `binFloor` (`bottom_height` in gf_bin_solid).
    var floorBlockHeight: Double {
        let override = configuration.internalHeightOverride
        return (override == 0 ? storageHeight - 0.1 : override)
            - fit.thickness - fit.vFitTolerance - fit.vPosTolerance
    }

    /// The top of the floor block, which is also the top of the dividers.
    var floorTop: Double { d.hBase + 0.1 + floorBlockHeight }

    /// The rounded rectangle that `binFloor` clips the pockets to, from z = 0 up to `height`.
    func interiorFootprint(height: Double) -> any Geometry3D {
        let aa = -(0.5 + d.dWall * 1.25 + fit.separatorWallThickness / 4)
        return roundedRect(height: height, addSize: aa, radius: d.rBase * 2)
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
        Union {
            d.blockBottom(height: floorBlockHeight, gridX: gridX, gridY: gridY)
            baseGridInterior()
        }
        .subtracting {
            let interiorCut = interiorFootprint(height: innerHeight)
                .translated(z: d.dWall)
            if let pockets {
                interiorCut.intersecting { pockets }
            } else {
                // Deliberately differs from OpenSCAD, which cuts nothing here (see binSolid).
                interiorCut
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
