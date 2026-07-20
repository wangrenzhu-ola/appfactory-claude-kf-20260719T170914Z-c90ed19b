import XCTest
@testable import ArrowTuneCore

final class AttributionTests: XCTestCase {
    private let gearID = UUID()
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_700_000_000))!
    }

    private func report(sessionOffset: Int, density: Double) -> (DiagnosisReport, Date) {
        let sessionID = UUID()
        let report = DiagnosisReport(
            sessionID: sessionID,
            centerOffsetX: 0.1, centerOffsetY: 0.1,
            densityRadius: density, spreadH: 0.1, spreadV: 0.1,
            patternLabel: "centered group", confidence: 0.8
        )
        return (report, day(sessionOffset))
    }

    func testEventAlignsWithNearestReportsBeforeAndAfter() {
        let (beforeReport, beforeDate) = report(sessionOffset: -3, density: 0.30)
        let (afterReport, afterDate) = report(sessionOffset: 2, density: 0.20)
        let change = TuningChange(gearID: gearID, changedAt: day(0), component: "Plunger", fromValue: "5.0", toValue: "5.5")
        let entries = AttributionTimeline.align(
            changes: [change],
            reports: [beforeReport, afterReport],
            reportDates: [beforeReport.sessionID: beforeDate, afterReport.sessionID: afterDate]
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].beforeReport?.reportID, beforeReport.reportID)
        XCTAssertEqual(entries[0].afterReport?.reportID, afterReport.reportID)
    }

    func testDensityDeltaNegativeMeansTighterGroup() {
        let (beforeReport, beforeDate) = report(sessionOffset: -3, density: 0.30)
        let (afterReport, afterDate) = report(sessionOffset: 2, density: 0.20)
        let change = TuningChange(gearID: gearID, changedAt: day(0), component: "Arrows", fromValue: "500 spine", toValue: "400 spine")
        let entry = AttributionTimeline.align(
            changes: [change],
            reports: [beforeReport, afterReport],
            reportDates: [beforeReport.sessionID: beforeDate, afterReport.sessionID: afterDate]
        )[0]
        XCTAssertEqual(AttributionTimeline.densityDelta(entry)!, -0.10, accuracy: 0.0001)
        XCTAssertEqual(AttributionTimeline.centerOffsetDelta(entry)!, 0.0, accuracy: 0.0001)
    }

    func testEventWithoutReportsYieldsNilComparisons() {
        let change = TuningChange(gearID: gearID, changedAt: day(0), component: "Sight", fromValue: "mark 3", toValue: "mark 4")
        let entries = AttributionTimeline.align(changes: [change], reports: [], reportDates: [:])
        XCTAssertNil(entries[0].beforeReport)
        XCTAssertNil(entries[0].afterReport)
        XCTAssertNil(AttributionTimeline.densityDelta(entries[0]))
    }

    func testEventsStayChronological() {
        let earlier = TuningChange(gearID: gearID, changedAt: day(-10), component: "A", fromValue: "1", toValue: "2")
        let later = TuningChange(gearID: gearID, changedAt: day(-2), component: "B", fromValue: "1", toValue: "2")
        let entries = AttributionTimeline.align(changes: [later, earlier], reports: [], reportDates: [:])
        XCTAssertEqual(entries.map(\.change.component), ["A", "B"])
    }
}
