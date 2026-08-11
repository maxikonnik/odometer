import Foundation

public enum GaugeZone: Equatable, Sendable {
    case normal
    case warning
    case critical
}

/// Maps a limit percentage onto the dial.
///
/// Angles are degrees measured clockwise from the positive X axis in a
/// y-down coordinate space, so 270 points straight up on screen. The sweep
/// runs from 150 (lower left) to 390 (lower right) and is deliberately left
/// unnormalized so callers can interpolate across the top of the dial.
public enum GaugeGeometry {
    public static let startDegrees: Double = 150
    public static let sweepDegrees: Double = 240

    public static func needleDegrees(percent: Double) -> Double {
        let clamped = min(max(percent, 0), 100)
        return startDegrees + (clamped / 100) * sweepDegrees
    }

    public static func zone(percent: Double) -> GaugeZone {
        if percent >= 80 { return .critical }
        if percent >= 60 { return .warning }
        return .normal
    }
}
