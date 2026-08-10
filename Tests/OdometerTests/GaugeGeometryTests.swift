import XCTest
@testable import OdometerCore

final class GaugeGeometryTests: XCTestCase {
    func testNeedleStartsAtLowerLeft() {
        XCTAssertEqual(GaugeGeometry.needleDegrees(percent: 0), 150, accuracy: 0.0001)
    }

    func testNeedlePointsStraightUpAtHalf() {
        XCTAssertEqual(GaugeGeometry.needleDegrees(percent: 50), 270, accuracy: 0.0001)
    }

    func testNeedleEndsAtLowerRight() {
        XCTAssertEqual(GaugeGeometry.needleDegrees(percent: 100), 390, accuracy: 0.0001)
    }

    func testNeedleClampsBelowZero() {
        XCTAssertEqual(GaugeGeometry.needleDegrees(percent: -25), 150, accuracy: 0.0001)
    }

    func testNeedleClampsAboveOneHundred() {
        XCTAssertEqual(GaugeGeometry.needleDegrees(percent: 150), 390, accuracy: 0.0001)
    }

    func testZoneBoundaries() {
        XCTAssertEqual(GaugeGeometry.zone(percent: 0), .normal)
        XCTAssertEqual(GaugeGeometry.zone(percent: 59.9), .normal)
        XCTAssertEqual(GaugeGeometry.zone(percent: 60), .warning)
        XCTAssertEqual(GaugeGeometry.zone(percent: 79.9), .warning)
        XCTAssertEqual(GaugeGeometry.zone(percent: 80), .critical)
        XCTAssertEqual(GaugeGeometry.zone(percent: 100), .critical)
    }
}
