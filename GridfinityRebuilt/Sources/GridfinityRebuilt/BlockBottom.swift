import Cadova

extension Dimensions {
    /// Ports OpenSCAD `block_bottom`: the solid floor block above the base.
    /// `height` is the block height along Z in mm, `gridX` and `gridY` are cell counts along X
    /// and Y, and `length` is the grid pitch in mm. Centered in XY, starting just above the base.
    public func blockBottom(
        height h: Double = 2.2,
        gridX gx: Double,
        gridY gy: Double,
        length: Double? = nil
    ) -> any Geometry3D {
        let l = length ?? lGrid
        return roundedRectangle(
            length: gx * l - 0.5 - dWall / 4,
            width: gy * l - 0.5 - dWall / 4,
            height: h,
            radius: rBase + 0.01
        )
        .translated(z: hBase + 0.1)
    }
}
