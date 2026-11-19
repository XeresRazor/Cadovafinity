import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_bin_lid, in the bin's own coordinates (the lid sits closed on the bin).
    func lidBody() -> any Geometry3D {
        let dh = storageHeight
        let sz = fit.plateInset
        let plateZ = dh + d.hBase - fit.thickness - fit.vPosTolerance
        let segments = configuration.cornerSegments

        // Rim of the lid: the wall sweep clipped to the lip mask, minus the grips.
        let rim = d.blockWall(gridX: gridX, gridY: gridY, profile: d.wallProfile(height: dh),
                              cornerSegments: segments)
            .intersecting { lidLipMask() }
            .subtracting {
                if let grips = lipGripMasks() { grips }
            }

        // Plate and inner lip, minus the tab notches.
        let lipProfile = d.wallProfile(height: dh)
            .subtracting {
                Rectangle([d.rBase, dh - fit.vPosTolerance])
                Rectangle([d.rBase, dh + d.hLip]).translated(x: d.rBase)
                lidLipWallProfile(lid: true).offset(amount: fit.lipClearance, style: .miter)
            }
        let plate = Union {
            roundedRect(height: fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
                .translated(z: plateZ)
            roundedRect(height: d.hLip + fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
                .translated(z: plateZ)
                .intersecting {
                    d.blockWall(gridX: gridX, gridY: gridY, profile: lipProfile,
                                cornerSegments: segments)
                }
        }
        .subtracting { lidTabs(adjust: true) }

        return Union { rim; plate }
    }
}
