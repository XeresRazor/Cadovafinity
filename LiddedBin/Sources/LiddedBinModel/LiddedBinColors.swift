import Cadova

/// The display colors of the four parts of the colored models. They are presentation only: they
/// name the color of each part in the exported 3MF and do not change the geometry, so they are
/// kept out of `LiddedBinConfiguration`.
public struct LiddedBinColors: Sendable, Equatable {
    /// The bin body: the wall with the lid slot and lip, the detent bumps, the floor and the feet.
    public var binBody: Color
    /// The dividers between the compartments, above the pocket floor.
    public var dividers: Color
    /// The lid's raised rim and the lip (tongue) that slides in the bin's slot.
    public var lidRim: Color
    /// The flat center of the lid inside the rim and the lip.
    public var lidCenter: Color

    public init(binBody: Color, dividers: Color, lidRim: Color, lidCenter: Color) {
        self.binBody = binBody
        self.dividers = dividers
        self.lidRim = lidRim
        self.lidCenter = lidCenter
    }

    /// Slate blue-grey for the bin body and the lid rim, orange dividers, a light grey lid center.
    public static let defaults = LiddedBinColors(
        binBody: Color(hex: "#587A9E"),
        dividers: Color(hex: "#E8912D"),
        lidRim: Color(hex: "#587A9E"),
        lidCenter: Color(hex: "#C8CDD6")
    )
}
