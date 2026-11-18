import Cadova
import Foundation

extension Dimensions {
    /// Ports OpenSCAD `profile_base`. 2D profile with X outward and Y as Z, in mm.
    public func baseProfile() -> any Geometry2D {
        Polygon([
            [0, 0],
            [0, hBase],
            [rBase, hBase],
            [rBase - rC2, hBase - rC2],
            [rBase - rC2, rC1],
            [rBase - rC2 - rC1, 0],
        ])
    }

    /// `profile_wall_sub_sub`.
    private func wallSubSub(height dh: Double) -> any Geometry2D {
        Polygon([
            [0, 0],
            [dWall / 2, 0],
            [dWall / 2, dh - 1.2 - dWall2 + dWall / 2],
            [dWall2 - dClear, dh - 1.2],
            [dWall2 - dClear, dh + hBase],
            [0, dh + hBase],
        ])
    }

    /// `profile_wall_sub`.
    private func wallSub(height dh: Double) -> any Geometry2D {
        wallSubSub(height: dh)
            .subtracting {
                baseProfile()
                    .flipped(along: .x)
                    .translated(x: rBase - dClear, y: dh)
                    .offset(amount: dClear, style: .miter)
            }
    }

    /// Ports OpenSCAD `profile_wall`: the wall cross-section with stacking lip.
    /// `height` is `$dh` in mm; X is outward, Y is Z.
    public func wallProfile(height dh: Double) -> any Geometry2D {
        wallSub(height: dh)
            .subtracting {
                // Round the top edge: remove the circle area not covered by the filleted profile.
                Circle(radius: rBase / 2)
                    .translated(y: dh + hBase - dClear * 2.0.squareRoot())
                    .subtracting {
                        wallSub(height: dh)
                            .offset(amount: -rF1, style: .miter)
                            .offset(amount: rF1, style: .round)
                    }

                // Remove any negative geometry in edge cases.
                Rectangle([100 * lGrid, 100 * lGrid])
                    .flipped(along: .y)
            }
            .flipped(along: .x)
            .translated(x: rBase)
    }

    /// Ports OpenSCAD `profile_wall2`: lipless wall profile.
    /// `height` is `$dh` in mm; X is outward, Y is Z.
    public func lipelessWallProfile(height dh: Double) -> any Geometry2D {
        Rectangle([dWall, dh])
            .flipped(along: .x)
            .translated(x: rBase)
    }
}
