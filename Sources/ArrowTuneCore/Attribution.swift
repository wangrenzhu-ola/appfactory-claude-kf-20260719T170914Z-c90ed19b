import Foundation

/// One tuning event aligned with the nearest diagnosis reports before and
/// after it on the shared timeline.
public struct AttributionEntry: Equatable, Sendable {
    public let change: TuningChange
    public let beforeReport: DiagnosisReport?
    public let afterReport: DiagnosisReport?

    public init(change: TuningChange, beforeReport: DiagnosisReport?, afterReport: DiagnosisReport?) {
        self.change = change
        self.beforeReport = beforeReport
        self.afterReport = afterReport
    }
}

/// Aligns the diagnosis-metric series with tuning-change events on one
/// timeline. Alignment is temporal only; it is a hint for review, never a
/// causal claim.
public enum AttributionTimeline {
    /// For each tuning change, find the latest report strictly before the
    /// change and the earliest report at or after it.
    public static func align(
        changes: [TuningChange],
        reports: [DiagnosisReport],
        reportDates: [UUID: Date]
    ) -> [AttributionEntry] {
        let datedReports: [(date: Date, report: DiagnosisReport)] = reports.compactMap { report in
            guard let date = reportDates[report.sessionID] else { return nil }
            return (date, report)
        }.sorted { $0.date < $1.date }

        return changes
            .sorted { $0.changedAt < $1.changedAt }
            .map { change in
                let before = datedReports.last(where: { $0.date < change.changedAt })?.report
                let after = datedReports.first(where: { $0.date >= change.changedAt })?.report
                return AttributionEntry(change: change, beforeReport: before, afterReport: after)
            }
    }

    /// Delta of the density radius between the after and before reports of one
    /// entry. Negative means the group tightened after the change.
    public static func densityDelta(_ entry: AttributionEntry) -> Double? {
        guard let before = entry.beforeReport, let after = entry.afterReport else { return nil }
        return after.densityRadius - before.densityRadius
    }

    /// Delta of the center-offset magnitude between the after and before reports.
    public static func centerOffsetDelta(_ entry: AttributionEntry) -> Double? {
        guard let before = entry.beforeReport, let after = entry.afterReport else { return nil }
        let beforeMag = (before.centerOffsetX * before.centerOffsetX
            + before.centerOffsetY * before.centerOffsetY).squareRoot()
        let afterMag = (after.centerOffsetX * after.centerOffsetX
            + after.centerOffsetY * after.centerOffsetY).squareRoot()
        return afterMag - beforeMag
    }
}
