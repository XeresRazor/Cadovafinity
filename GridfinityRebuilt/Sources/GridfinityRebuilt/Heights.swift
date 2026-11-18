import Foundation

/// What the bin's `z` value means (`gridz_define` in the OpenSCAD files).
public enum HeightMode: Int, Sendable {
    /// `z` is the height in units of 7mm (Zack's method).
    case units = 0
    /// `z` is the internal height in millimeters.
    case internalMillimeters = 1
    /// `z` is the overall external height in millimeters.
    case externalMillimeters = 2
}

/// Lip style of a bin (`sl` in `gridfinityInit`, `l` in `height`).
public enum LipStyle: Int, Sendable {
    /// Regular stacking lip.
    case regular = 0
    /// Lip removed subtractively.
    case removed = 1
    /// Lip removed, overall height retained.
    case removedKeepHeight = 2
}

extension Dimensions {
    /// Port of OpenSCAD `hf`.
    func rawHeight(_ z: Double, mode: HeightMode, lip: LipStyle) -> Double {
        let base: Double
        switch mode {
        case .units: base = z * 7
        case .internalMillimeters: base = hBot + z + hBase
        case .externalMillimeters: base = z - (lip == .removed ? hLip : 0)
        }
        return base + (lip == .removedKeepHeight ? hLip : 0)
    }

    /// Port of OpenSCAD `height`: the storage height `$dh` of a bin, in millimeters.
    ///
    /// With `snap`, the value is rounded up to a multiple of 7mm first.
    public func binHeight(
        _ z: Double,
        mode: HeightMode = .units,
        lip: LipStyle = .regular,
        snap: Bool = true
    ) -> Double {
        let h = rawHeight(z, mode: mode, lip: lip)
        let snapped: Double
        if snap {
            let r = abs(h).truncatingRemainder(dividingBy: 7)
            snapped = r == 0 ? h : h + 7 - r
        } else {
            snapped = h
        }
        return snapped - hBase
    }
}
