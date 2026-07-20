import XCTest
@testable import ArrowTuneCore

final class GroupMetricsTests: XCTestCase {
    func testKnownCoordinateSet() {
        // Square corners around center: centroid (0,0), density = sqrt(0.02),
        // spreadH = spreadV = 0.1
        let points = [(0.1, 0.1), (0.1, -0.1), (-0.1, 0.1), (-0.1, -0.1)]
        let metrics = try! GroupMetricsCalculator.metrics(forPoints: points)
        XCTAssertEqual(metrics.centerOffsetX, 0, accuracy: 0.0001)
        XCTAssertEqual(metrics.centerOffsetY, 0, accuracy: 0.0001)
        XCTAssertEqual(metrics.densityRadius, (0.02 as Double).squareRoot(), accuracy: 0.0001)
        XCTAssertEqual(metrics.spreadH, 0.1, accuracy: 0.0001)
        XCTAssertEqual(metrics.spreadV, 0.1, accuracy: 0.0001)
        XCTAssertEqual(metrics.impactCount, 4)
    }

    func testOffCenterGroupReportsOffset() {
        let points = [(0.4, 0.2), (0.5, 0.3), (0.3, 0.1)]
        let metrics = try! GroupMetricsCalculator.metrics(forPoints: points)
        XCTAssertEqual(metrics.centerOffsetX, 0.4, accuracy: 0.0001)
        XCTAssertEqual(metrics.centerOffsetY, 0.2, accuracy: 0.0001)
    }

    func testInsufficientDataThrows() {
        XCTAssertThrowsError(try GroupMetricsCalculator.metrics(forPoints: [])) { error in
            XCTAssertEqual(error as? GroupMetricsError, .insufficientData)
        }
        XCTAssertThrowsError(try GroupMetricsCalculator.metrics(forPoints: [(0.1, 0.1)])) { error in
            XCTAssertEqual(error as? GroupMetricsError, .insufficientData)
        }
    }

    func testTwoImpactsIsMinimumViableGroup() {
        let metrics = try! GroupMetricsCalculator.metrics(forPoints: [(0.0, 0.0), (0.2, 0.0)])
        XCTAssertEqual(metrics.impactCount, 2)
        XCTAssertEqual(metrics.densityRadius, 0.1, accuracy: 0.0001)
    }
}
