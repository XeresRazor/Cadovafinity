import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_bin_lid, in the bin's own coordinates (the lid sits closed on the bin): the union of
    /// `lidRimAndLip()` and `lidCenter()`.
    func lidBody() -> any Geometry3D {
        Union {
            lidRimAndLip()
            lidCenter()
        }
    }

    /// The "Lid rim and lip" part: the raised rim, the tongue that slides in the bin's slot and
    /// the edge band (the plate within `lidEdgeBand` of its outline, for the full plate
    /// thickness), minus the tab notches. It is gf_bin_lid minus `lidCenter()`.
    func lidRimAndLip() -> any Geometry3D {
        droppingEmptyShells(
            Union {
                lidRim()
                Union { lidPlateSlab(); lidTongue() }.subtracting { lidTabs(adjust: true) }
            }
            .subtracting { lidCenterSolid() }
        )
    }

    /// The "Lid center" part: the plate inside the edge band (the plate's footprint inset by
    /// `lidEdgeBand`, over the plate thickness), minus the tab notches. Together with
    /// `lidRimAndLip()` it is exactly gf_bin_lid.
    func lidCenter() -> any Geometry3D {
        droppingEmptyShells(lidCenterSolid())
    }

    /// The width in mm of the lid's edge band: the horizontal width of the tongue's foot on the
    /// long sides, from the plate edge to the tongue's inner face, so that the band lies under
    /// the tongue there. Measured inward from the outer wall face (the block outline less 0.25):
    /// - the tongue's inner face is the lip's inner face in `profile_wall`, `dWall2 - dClear`
    ///   (2.596) in, and `blockWall` sets the outer wall face 0.0005 further in;
    /// - the plate edge is the slot face (`wallThickness`, 1.2) plus the side clearance (the Lid
    ///   clearance control, 0.20 by default) in, and `roundedRect` moves it 0.0025 out.
    /// So the band is `dWall2 - dClear - wallThickness - sideClearance + 0.003`: 1.199 at the
    /// default clearance. It narrows as the clearance grows (0.799 at the 0.6 maximum) and stays
    /// below the plate's corner radius, so the inset keeps rounded corners.
    var lidEdgeBand: Double {
        let footIn = d.dWall2 - d.dClear + 0.25 + 0.0005
        let plateEdgeIn = (fit.plateInset - 0.005) / 2
        return footIn - plateEdgeIn
    }

    /// The plan outline of the lid's plate (and of the tongue's outer face).
    func lidPlateFootprint() -> any Geometry2D {
        let sz = fit.plateInset
        return roundedRect2D(addSize: -sz, radius: d.rFo1 - sz)
    }

    /// The center before the empty shells are dropped: the plate slab inside the edge band. The
    /// inset footprint is extruded past the plate on both sides, so the center's top and bottom
    /// are the slab's own faces.
    private func lidCenterSolid() -> any Geometry3D {
        lidPlateSlab()
            .intersecting {
                lidPlateFootprint()
                    .offset(amount: -lidEdgeBand, style: .round)
                    .extruded(height: fit.thickness + 2)
                    .translated(z: lidPlateZ - 1)
            }
            .subtracting { lidTabs(adjust: true) }
    }

    /// The bottom of the lid's plate, in the bin's coordinates.
    var lidPlateZ: Double { storageHeight + d.hBase - fit.thickness - fit.vPosTolerance }

    /// Rim of the lid: the wall sweep clipped to the lip mask, minus the grips.
    func lidRim() -> any Geometry3D {
        d.blockWall(gridX: gridX, gridY: gridY, profile: d.wallProfile(height: storageHeight),
                    cornerSegments: configuration.cornerSegments)
            .intersecting { lidLipMask() }
            .subtracting {
                if let grips = lipGripMasks() { grips }
            }
    }

    /// The flat plate of the lid, before the tab notches.
    func lidPlateSlab() -> any Geometry3D {
        let sz = fit.plateInset
        return roundedRect(height: fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
            .translated(z: lidPlateZ)
    }

    /// The inner lip (tongue) of the lid, before the tab notches: the plate outline extruded
    /// through the plate and the lip height, clipped to the lip profile swept round the wall.
    func lidTongue() -> any Geometry3D {
        let dh = storageHeight
        let sz = fit.plateInset
        let lipProfile = d.wallProfile(height: dh)
            .subtracting {
                Rectangle([d.rBase, dh - fit.vPosTolerance])
                Rectangle([d.rBase, dh + d.hLip]).translated(x: d.rBase)
                lidLipWallProfile(lid: true).offset(amount: fit.lipClearance, style: .miter)
            }
        return roundedRect(height: d.hLip + fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
            .translated(z: lidPlateZ)
            .intersecting {
                d.blockWall(gridX: gridX, gridY: gridY, profile: lipProfile,
                            cornerSegments: configuration.cornerSegments)
            }
    }
}
