import Testing
@testable import OdometerCore

@Suite struct GaugeGeometryTests {
    @Test func needleStartsAtLowerLeft() {
        #expect(abs(GaugeGeometry.needleDegrees(percent: 0) - 150) < 0.0001)
    }

    @Test func needlePointsStraightUpAtHalf() {
        #expect(abs(GaugeGeometry.needleDegrees(percent: 50) - 270) < 0.0001)
    }

    @Test func needleEndsAtLowerRight() {
        #expect(abs(GaugeGeometry.needleDegrees(percent: 100) - 390) < 0.0001)
    }

    @Test func needleClampsBelowZero() {
        #expect(abs(GaugeGeometry.needleDegrees(percent: -25) - 150) < 0.0001)
    }

    @Test func needleClampsAboveOneHundred() {
        #expect(abs(GaugeGeometry.needleDegrees(percent: 150) - 390) < 0.0001)
    }

    @Test func zoneBoundaries() {
        #expect(GaugeGeometry.zone(percent: 0) == .normal)
        #expect(GaugeGeometry.zone(percent: 59.9) == .normal)
        #expect(GaugeGeometry.zone(percent: 60) == .warning)
        #expect(GaugeGeometry.zone(percent: 79.9) == .warning)
        #expect(GaugeGeometry.zone(percent: 80) == .critical)
        #expect(GaugeGeometry.zone(percent: 100) == .critical)
    }
}
