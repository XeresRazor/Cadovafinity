import Cadova

/// A centered rectangle whose corners are rounded with the given radius, the 2D part of
/// OpenSCAD `rounded_rectangle`. `length` is along X, `width` along Y, all in mm.
public func roundedRectangle2D(length: Double, width: Double, radius: Double) -> any Geometry2D {
    Rectangle([length, width])
        .aligned(at: .center)
        .offset(amount: -radius, style: .round)
        .offset(amount: radius, style: .round)
}

/// Ports OpenSCAD `rounded_rectangle`: centered in XY, from z = 0 up to `height`.
/// `length` is along X, `width` along Y, all in mm.
public func roundedRectangle(length: Double, width: Double, height: Double, radius: Double) -> any Geometry3D {
    roundedRectangle2D(length: length, width: width, radius: radius)
        .extruded(height: height)
}
