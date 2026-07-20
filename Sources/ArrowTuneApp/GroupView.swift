import SwiftUI

/// /session/{id}/group — quantified group shape: centroid offset, density
/// radius, horizontal/vertical spread, with the density-ellipse overlay.
/// Degrades honestly to an insufficient-data state under two arrows.
struct GroupView: View {
    @EnvironmentObject var state: AppState
    let session: Session

    private var impacts: [ArrowImpact] { state.confirmedImpacts(for: session) }
    private var metrics: GroupMetrics? { state.draftMetrics(for: session) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TargetFaceView(
                    face: session.targetFace,
                    impacts: impacts,
                    metrics: metrics,
                    showsOverlay: metrics != nil
                )
                if let metrics {
                    metricGrid(metrics)
                    NavigationLink(destination: DiagnosisDetailView(session: session)) {
                        Label("Review diagnosis", systemImage: "stethoscope")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.ink)
                            .foregroundColor(.white)
                    }
                    .accessibilityHint("Opens the on-device diagnosis for this group")
                } else {
                    insufficientData
                }
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Group")
    }

    private func metricGrid(_ metrics: GroupMetrics) -> some View {
        let radiusCm = session.targetFace.scoringRadiusCm
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Measured group shape")
            HStack(spacing: 8) {
                MetricCell(label: "Center offset X",
                           value: String(format: "%+.1f", metrics.centerOffsetX * radiusCm), unit: "cm")
                MetricCell(label: "Center offset Y",
                           value: String(format: "%+.1f", metrics.centerOffsetY * radiusCm), unit: "cm")
            }
            HStack(spacing: 8) {
                MetricCell(label: "Density radius",
                           value: String(format: "%.1f", metrics.densityRadius * radiusCm), unit: "cm")
                MetricCell(label: "Impacts",
                           value: "\(metrics.impactCount)", unit: "arrows")
            }
            HStack(spacing: 8) {
                MetricCell(label: "Spread horizontal",
                           value: String(format: "%.1f", metrics.spreadH * radiusCm), unit: "cm")
                MetricCell(label: "Spread vertical",
                           value: String(format: "%.1f", metrics.spreadV * radiusCm), unit: "cm")
            }
        }
    }

    private var insufficientData: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusBar(kind: .info, text: "Not enough arrows to compute group metrics")
            HStack(spacing: 8) {
                MetricCell(label: "Center offset", value: "--", unit: "cm")
                MetricCell(label: "Density radius", value: "--", unit: "cm")
            }
            Text("Confirm at least two arrows on the scoring screen and the group shape appears here automatically.")
                .font(.footnote)
                .foregroundColor(Theme.inkSoft)
        }
        .accessibilityElement(children: .contain)
    }
}
