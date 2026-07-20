import SwiftUI

/// /attribution — dual-track timeline aligning the diagnosis-metric series
/// with tuning events. Selecting an event highlights the before/after metric
/// window. Wording stays a temporal hint, never a causal claim. Comparing
/// across multiple gear profiles is a Pro capability.
struct AttributionView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedGearID: UUID?
    @State private var selectedChangeID: UUID?
    @State private var showsPaywall = false

    private var multiGear: Bool { state.gear.count > 1 }
    private var entries: [AttributionEntry] { state.attributionEntries(gearID: selectedGearID) }
    private var series: [(date: Date, report: DiagnosisReport)] { state.reportSeries(gearID: selectedGearID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gearFilter
                if entries.isEmpty && series.isEmpty {
                    emptyState
                } else {
                    metricTrack
                    eventTrack
                    if let selected = selectedEntry {
                        comparisonCard(selected)
                    }
                }
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Attribution")
        .sheet(isPresented: $showsPaywall) {
            PaywallView(trigger: .multiGearCompare, isPresented: $showsPaywall)
                .environmentObject(state.pro)
        }
    }

    private var selectedEntry: AttributionEntry? {
        entries.first { $0.change.changeID == selectedChangeID }
    }

    private var gearFilter: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Gear")
            Picker("Gear filter", selection: $selectedGearID) {
                Text("Current gear").tag(UUID?.none)
                ForEach(state.gear) { gear in
                    Text(gear.name).tag(UUID?.some(gear.gearID))
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Filter timeline by gear profile")
            if multiGear && !state.pro.isPro {
                Button { showsPaywall = true } label: {
                    Label("Compare across gear profiles with Pro", systemImage: "lock")
                        .font(.footnote)
                        .foregroundColor(Theme.signal)
                }
                .accessibilityHint("Opens the Pro unlock options")
            }
        }
    }

    /// Upper track: density-radius line across confirmed reports.
    private var metricTrack: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Group density over time")
            if series.isEmpty {
                Text("No confirmed diagnoses yet. Confirm a diagnosis from a session's group view to start the series.")
                    .font(.footnote)
                    .foregroundColor(Theme.inkSoft)
            } else {
                MetricLineView(series: series, highlightChangeID: selectedChangeID,
                               changes: entries.map(\.change))
                    .frame(height: 120)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Density radius line over \(series.count) confirmed diagnoses")
            }
        }
    }

    /// Lower track: tuning events as diamond markers on the same time axis.
    private var eventTrack: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Tuning events")
            if entries.isEmpty {
                Text("No tuning changes recorded yet. Record one from a gear profile.")
                    .font(.footnote)
                    .foregroundColor(Theme.inkSoft)
            } else {
                ForEach(entries, id: \.change.changeID) { entry in
                    Button {
                        selectedChangeID = (selectedChangeID == entry.change.changeID) ? nil : entry.change.changeID
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 9))
                                .foregroundColor(selectedChangeID == entry.change.changeID ? Theme.signal : Theme.inkSoft)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.change.component)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.ink)
                                Text("\(entry.change.fromValue) → \(entry.change.toValue)")
                                    .font(.system(.caption, design: .monospaced).monospacedDigit())
                                    .foregroundColor(Theme.signal)
                            }
                            Spacer()
                            Text(entry.change.changedAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(Theme.inkSoft)
                        }
                        .padding(10)
                        .background(selectedChangeID == entry.change.changeID ? Theme.signal.opacity(0.08) : Theme.cardGround)
                        .overlay(Rectangle().stroke(selectedChangeID == entry.change.changeID ? Theme.signal : Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tuning event \(entry.change.component), from \(entry.change.fromValue) to \(entry.change.toValue)")
                    .accessibilityHint("Shows group metrics before and after this change")
                }
            }
        }
    }

    /// Before/after readout for the selected event — a temporal alignment
    /// hint, explicitly not a causal verdict.
    private func comparisonCard(_ entry: AttributionEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Around this change")
            HStack(spacing: 8) {
                MetricCell(label: "Density before",
                           value: formattedDensity(entry.beforeReport), unit: "cm")
                MetricCell(label: "Density after",
                           value: formattedDensity(entry.afterReport), unit: "cm")
            }
            HStack(spacing: 8) {
                MetricCell(label: "Offset before",
                           value: formattedOffset(entry.beforeReport), unit: "cm")
                MetricCell(label: "Offset after",
                           value: formattedOffset(entry.afterReport), unit: "cm")
            }
            if let delta = AttributionTimeline.densityDelta(entry) {
                let face = faceForSession(entry.afterReport?.sessionID)
                let cm = delta * (face?.scoringRadiusCm ?? 20)
                StatusBar(kind: .info,
                          text: String(format: "Density shifted %+.1f cm across this change — a time alignment, not proof of cause.", cm))
            } else {
                StatusBar(kind: .info,
                          text: "Need a confirmed diagnosis on both sides of this change to compare.")
            }
        }
        .padding(14)
        .background(Theme.cardGround)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
    }

    private func faceForSession(_ id: UUID?) -> TargetFace? {
        state.session(id: id)?.targetFace
    }

    private func formattedDensity(_ report: DiagnosisReport?) -> String {
        guard let report else { return "--" }
        let face = faceForSession(report.sessionID) ?? .full40cm
        return String(format: "%.1f", report.densityRadius * face.scoringRadiusCm)
    }

    private func formattedOffset(_ report: DiagnosisReport?) -> String {
        guard let report else { return "--" }
        let face = faceForSession(report.sessionID) ?? .full40cm
        let magnitude = (report.centerOffsetX * report.centerOffsetX
            + report.centerOffsetY * report.centerOffsetY).squareRoot()
        return String(format: "%.1f", magnitude * face.scoringRadiusCm)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 44))
                .foregroundColor(Theme.inkSoft)
                .accessibilityHidden(true)
            Text("Nothing to align yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(Theme.ink)
            Text("Confirm a diagnosis after scoring and record a tuning change on your gear — the timeline lines them up here.")
                .font(.subheadline)
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// Density-radius line with tuning-change tick marks on a shared time axis.
struct MetricLineView: View {
    let series: [(date: Date, report: DiagnosisReport)]
    let highlightChangeID: UUID?
    let changes: [TuningChange]

    var body: some View {
        GeometryReader { geo in
            let dates = series.map(\.date) + changes.map(\.changedAt)
            let minDate = dates.min() ?? Date()
            let maxDate = dates.max() ?? Date().addingTimeInterval(1)
            let span = max(maxDate.timeIntervalSince(minDate), 1)
            let maxDensity = max(series.map(\.report.densityRadius).max() ?? 1, 0.01)

            let point = { (entry: (date: Date, report: DiagnosisReport)) -> CGPoint in
                CGPoint(x: CGFloat(entry.date.timeIntervalSince(minDate) / span) * geo.size.width,
                        y: geo.size.height - CGFloat(entry.report.densityRadius / maxDensity) * (geo.size.height - 12) - 6)
            }

            Canvas { context, size in
                // Axis ticks.
                for i in 0...4 {
                    let x = CGFloat(i) / 4 * size.width
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: size.height - 6))
                    tick.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(tick, with: .color(Theme.hairline), lineWidth: 1)
                }
                // Metric line.
                if series.count > 1 {
                    var line = Path()
                    for (index, entry) in series.enumerated() {
                        let p = point(entry)
                        if index == 0 { line.move(to: p) } else { line.addLine(to: p) }
                    }
                    context.stroke(line, with: .color(Theme.ink), lineWidth: 1.4)
                }
                for entry in series {
                    let p = point(entry)
                    let dot = Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                    context.fill(dot, with: .color(Theme.ink))
                }
                // Tuning-change markers on the same axis.
                for change in changes {
                    let x = CGFloat(change.changedAt.timeIntervalSince(minDate) / span) * size.width
                    let isHighlighted = change.changeID == highlightChangeID
                    var diamond = Path()
                    let r: CGFloat = isHighlighted ? 6 : 4
                    diamond.move(to: CGPoint(x: x, y: size.height - 12 - r))
                    diamond.addLine(to: CGPoint(x: x + r, y: size.height - 12))
                    diamond.addLine(to: CGPoint(x: x, y: size.height - 12 + r))
                    diamond.addLine(to: CGPoint(x: x - r, y: size.height - 12))
                    diamond.closeSubpath()
                    context.fill(diamond, with: .color(isHighlighted ? Theme.signal : Theme.inkSoft))
                    if isHighlighted {
                        var rule = Path()
                        rule.move(to: CGPoint(x: x, y: 0))
                        rule.addLine(to: CGPoint(x: x, y: size.height - 12))
                        context.stroke(rule, with: .color(Theme.signal.opacity(0.5)), style: .init(lineWidth: 1, dash: [3, 3]))
                    }
                }
            }
        }
    }
}
