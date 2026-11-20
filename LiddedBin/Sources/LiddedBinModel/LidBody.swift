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

    /// The "Lid rim and lip" part: the raised rim and the tongue that slides in the bin's slot,
    /// minus the tab notches.
    func lidRimAndLip() -> any Geometry3D {
        Union {
            lidRim()
            lidTongue().subtracting { lidTabs(adjust: true) }
        }
    }

    /// The "Lid center" part: the flat plate inside the rim and the tongue, minus the tab notches.
    /// Together with `lidRimAndLip()` it is exactly gf_bin_lid.
    func lidCenter() -> any Geometry3D {
        lidPlateSlab()
            .subtracting {
                lidRim()
                lidTongue()
                lidTabs(adjust: true)
            }
    }

    /// The bottom of the lid's plate, in the bin's coordinates.
    private var lidPlateZ: Double { storageHeight + d.hBase - fit.thickness - fit.vPosTolerance }

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
