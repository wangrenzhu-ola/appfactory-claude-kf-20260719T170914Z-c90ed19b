import SwiftUI

/// /diagnosis/{id} — on-device group-shape diagnosis with user review.
/// Nothing is persisted until Confirm; wording states a temporal hint, never
/// a causal claim, and every report carries its confidence.
struct DiagnosisDetailView: View {
    @EnvironmentObject var state: AppState
    let session: Session

    @State private var note: String = ""
    @State private var saved = false

    private var diagnosis: Diagnosis? { state.draftDiagnosis(for: session) }
    private var existing: DiagnosisReport? { state.latestReport(for: session) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let diagnosis {
                    diagnosisCard(diagnosis)
                } else {
                    StatusBar(kind: .info, text: "Not enough arrows to compute group metrics")
                    Text("Confirm at least two arrows first, then the diagnosis can be reviewed here.")
                        .font(.footnote)
                        .foregroundColor(Theme.inkSoft)
                }
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Diagnosis")
        .onAppear {
            note = existing?.userNote ?? ""
        }
    }

    private func diagnosisCard(_ diagnosis: Diagnosis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "Pattern")
                Spacer()
                Text(String(format: "confidence %.0f%%", diagnosis.confidence * 100))
                    .font(.system(.caption, design: .monospaced).monospacedDigit())
                    .foregroundColor(Theme.inkSoft)
                    .accessibilityLabel(String(format: "Diagnosis confidence %.0f percent", diagnosis.confidence * 100))
            }
            Text(diagnosis.patternLabel)
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(Theme.signal)

            SectionLabel(text: "Possible contributing factors")
            ForEach(diagnosis.possibleCauses, id: \.self) { cause in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundColor(Theme.inkSoft)
                        .padding(.top, 6)
                    Text(cause)
                        .font(.footnote)
                        .foregroundColor(Theme.ink)
                }
            }
            Text("This readout compares measurements over time. It does not prove any single tuning change caused the shift.")
                .font(.caption)
                .foregroundColor(Theme.inkSoft)

            SectionLabel(text: "Your note")
            TextEditor(text: $note)
                .frame(minHeight: 80)
                .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                .accessibilityLabel("Diagnosis note")

            if saved {
                StatusBar(kind: .success, text: "Diagnosis saved to this session.")
            }

            Button {
                if state.confirmDiagnosis(session: session, note: note) {
                    saved = true
                }
            } label: {
                Text(saved ? "Saved" : "Confirm diagnosis")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(saved ? Theme.ok : Theme.ink)
                    .foregroundColor(.white)
            }
            .disabled(saved)
            .accessibilityHint("Writes this diagnosis to the session; before confirming it stays a draft")
        }
        .padding(14)
        .background(Theme.cardGround)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
    }
}
