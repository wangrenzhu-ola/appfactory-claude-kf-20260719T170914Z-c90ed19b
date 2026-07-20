import XCTest
@testable import ArrowTuneCore

final class DiagnosisTests: XCTestCase {
    private func metrics(x: Double, y: Double, density: Double, h: Double, v: Double, count: Int = 12) -> GroupMetrics {
        GroupMetrics(centerOffsetX: x, centerOffsetY: y, densityRadius: density, spreadH: h, spreadV: v, impactCount: count)
    }

    func testLeftDriftDiagnosis() {
        let diagnosis = DiagnosisEngine.diagnose(metrics: metrics(x: -0.25, y: 0, density: 0.2, h: 0.1, v: 0.1))
        XCTAssertTrue(diagnosis.patternLabel.contains("left drift"))
        XCTAssertFalse(diagnosis.possibleCauses.isEmpty)
    }

    func testVerticalStringingDiagnosis() {
        let diagnosis = DiagnosisEngine.diagnose(metrics: metrics(x: 0, y: 0, density: 0.3, h: 0.05, v: 0.2))
        XCTAssertTrue(diagnosis.patternLabel.contains("vertical stringing"))
    }

    func testTightCenteredGroup() {
        let diagnosis = DiagnosisEngine.diagnose(metrics: metrics(x: 0.02, y: -0.01, density: 0.1, h: 0.05, v: 0.05))
        XCTAssertTrue(diagnosis.patternLabel.contains("tight group"))
    }

    func testLooseGroupFlaggedWithCause() {
        let diagnosis = DiagnosisEngine.diagnose(metrics: metrics(x: 0, y: 0, density: 0.6, h: 0.3, v: 0.3))
        XCTAssertTrue(diagnosis.patternLabel.contains("loose group"))
        XCTAssertTrue(diagnosis.possibleCauses.contains { $0.contains("inconsistent form") })
    }

    func testConfidenceBounds() {
        let few = DiagnosisEngine.diagnose(metrics: metrics(x: 0, y: 0, density: 0.2, h: 0.1, v: 0.1, count: 2))
        let many = DiagnosisEngine.diagnose(metrics: metrics(x: 0, y: 0, density: 0.2, h: 0.1, v: 0.1, count: 36))
        XCTAssertGreaterThan(many.confidence, few.confidence)
        XCTAssertLessThanOrEqual(many.confidence, 0.95)
        XCTAssertGreaterThanOrEqual(few.confidence, 0.2)
    }

    func testReportBuildsFromImpacts() {
        let endID = UUID()
        let sessionID = UUID()
        let impacts = [(0.1, 0.1), (0.12, 0.08), (0.08, 0.12)].map {
            ArrowImpact(endID: endID, xNorm: $0.0, yNorm: $0.1, ringValue: 9, source: .manual, confirmed: true)
        }
        let report = try! DiagnosisEngine.report(sessionID: sessionID, impacts: impacts)
        XCTAssertEqual(report.sessionID, sessionID)
        XCTAssertNil(report.confirmedAt)
        XCTAssertFalse(report.patternLabel.isEmpty)
    }
}
