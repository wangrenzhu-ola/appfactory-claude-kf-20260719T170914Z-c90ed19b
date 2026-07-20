import SwiftUI
import UIKit

/// /session/{id}/score — per-end arrow entry. Photo path: on-device detection
/// produces editable proposals; nothing persists until Confirm. Manual tap
/// entry is capability-equivalent and always available, including after a
/// detection failure — already-entered arrows are never dropped.
struct ScoringView: View {
    @EnvironmentObject var state: AppState
    let session: Session
    var autoStartEnd: Bool = false

    @State private var draft = ScoringDraft()
    @State private var endID = UUID()
    @State private var detectionState: DetectionState = .idle
    @State private var showsPhotoSource = false
    @State private var showsCamera = false
    @State private var selectedImpactID: UUID?
    @State private var endCounter: Int = 1

    private enum DetectionState: Equatable {
        case idle
        case analyzing
        case failed(String)
    }

    private var ends: [End] { state.ends(for: session) }
    private var expectedArrows: Int { session.arrowsPerEnd }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                targetSection
                controls
                if case .failed(let reason) = detectionState {
                    StatusBar(kind: .failure, text: "\(reason) You can finish this end by tapping the target — nothing you entered is lost.")
                    Button {
                        detectionState = .idle
                    } label: {
                        Label("Switch to manual entry", systemImage: "hand.tap")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.ink)
                            .foregroundColor(.white)
                    }
                    .accessibilityHint("Continues with manual tap entry; detected proposals stay editable")
                }
                if case .analyzing = detectionState {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading arrow holes on this device…")
                            .font(.footnote)
                            .foregroundColor(Theme.inkSoft)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Analyzing photo on this device")
                }
                endsSection
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Scoring")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: GroupView(session: session)) {
                    Label("Group", systemImage: "chart.dots.scatter")
                }
                .accessibilityLabel("Open group view")
            }
        }
        .sheet(isPresented: $showsPhotoSource) {
            PhotoLibraryPicker { image in
                showsPhotoSource = false
                if let image { analyze(image) }
            } onCancel: {
                showsPhotoSource = false
            }
        }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { analyze(image) }
            } onCancel: {
                showsCamera = false
            }
        }
        .onAppear {
            if autoStartEnd {
                endCounter = (ends.last?.endIndex ?? 0) + 1
            } else {
                endCounter = (ends.last?.endIndex ?? 0) + 1
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("End \(endCounter)")
                .font(.title2).fontWeight(.semibold)
                .foregroundColor(Theme.ink)
            Text("\(session.distanceM) m · \(session.targetFace.displayName) · \(expectedArrows) arrows")
                .font(.caption)
                .foregroundColor(Theme.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private var targetSection: some View {
        VStack(spacing: 8) {
            TargetFaceView(
                face: session.targetFace,
                impacts: [],
                draftImpacts: draft.impacts,
                metrics: nil,
                showsOverlay: false,
                onTap: { x, y in
                    guard draft.impacts.count < 24 else { return }
                    draft.addManualImpact(xNorm: x, yNorm: y, endID: endID)
                    selectedImpactID = nil
                },
                onMoveDraftImpact: { id, x, y in
                    draft.moveImpact(id: id, toX: x, toY: y)
                }
            )
            HStack {
                Text("End total")
                    .font(.caption)
                    .foregroundColor(Theme.inkSoft)
                Spacer()
                Text("\(draft.scoreTotal)")
                    .font(.system(.title3, design: .monospaced).monospacedDigit())
                    .foregroundColor(Theme.signal)
                Text("/ \(expectedArrows * 10)")
                    .font(.caption)
                    .foregroundColor(Theme.inkSoft)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("End total \(draft.scoreTotal) of \(expectedArrows * 10)")
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Button { showsCamera = true } label: {
                        Label("Take photo", systemImage: "camera")
                    }
                    Button { showsPhotoSource = true } label: {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Read photo", systemImage: "camera.viewfinder")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.signal)
                        .foregroundColor(.white)
                }
                .accessibilityHint("Detects arrows on this device; you review and confirm before anything is saved")
                Button {
                    draft.discard()
                    endID = UUID()
                    selectedImpactID = nil
                } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                        .foregroundColor(Theme.ink)
                }
                .disabled(draft.impacts.isEmpty)
                .accessibilityHint("Discards unconfirmed arrows in this end")
            }

            if !draft.impacts.isEmpty {
                proposalEditor
            }

            Button {
                confirmEnd()
            } label: {
                Text("Confirm end")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(draft.impacts.isEmpty ? Theme.hairline : Theme.ink)
                    .foregroundColor(.white)
            }
            .disabled(draft.impacts.isEmpty)
            .accessibilityHint("Writes the confirmed arrows to this session")
        }
    }

    /// Editable proposal list: each impact can be nudged in four directions
    /// (VoiceOver-operable replacement for drag) or removed.
    private var proposalEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Proposals — edit before confirming")
            ForEach(draft.impacts) { impact in
                HStack(spacing: 8) {
                    Text("Ring \(impact.ringValue)")
                        .font(.system(.callout, design: .monospaced).monospacedDigit())
                        .frame(width: 70, alignment: .leading)
                    Spacer()
                    stepperButtons(for: impact)
                    Button(role: .destructive) {
                        draft.removeImpact(id: impact.impactID)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .accessibilityLabel("Remove arrow at ring \(impact.ringValue)")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Theme.cardGround)
                .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private func stepperButtons(for impact: ArrowImpact) -> some View {
        let step = 0.01
        return HStack(spacing: 4) {
            nudgeButton(impact, dx: -step, dy: 0, icon: "arrow.left", label: "Nudge left")
            nudgeButton(impact, dx: step, dy: 0, icon: "arrow.right", label: "Nudge right")
            nudgeButton(impact, dx: 0, dy: step, icon: "arrow.up", label: "Nudge up")
            nudgeButton(impact, dx: 0, dy: -step, icon: "arrow.down", label: "Nudge down")
        }
    }

    private func nudgeButton(_ impact: ArrowImpact, dx: Double, dy: Double, icon: String, label: String) -> some View {
        Button {
            draft.moveImpact(id: impact.impactID, toX: impact.xNorm + dx, toY: impact.yNorm + dy)
        } label: {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
        }
        .accessibilityLabel("\(label), arrow scoring \(impact.ringValue)")
    }

    private var endsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Recorded ends")
            if ends.isEmpty {
                Text("No ends recorded yet. Tap the target or read a photo to start end \(endCounter).")
                    .font(.footnote)
                    .foregroundColor(Theme.inkSoft)
            } else {
                ForEach(ends) { end in
                    HStack {
                        Text("End \(end.endIndex)")
                            .foregroundColor(Theme.ink)
                        Spacer()
                        Text("\(end.scoreTotal)")
                            .font(.system(.body, design: .monospaced).monospacedDigit())
                            .foregroundColor(Theme.signal)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Theme.cardGround)
                    .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("End \(end.endIndex), \(end.scoreTotal) points")
                }
            }
        }
    }

    // MARK: - Detection

    private func analyze(_ image: UIImage) {
        detectionState = .analyzing
        let currentEndID = endID
        let expected = expectedArrows
        Task.detached(priority: .userInitiated) {
            let outcome = await TargetPhotoAnalyzer.analyze(image: image, expectedArrows: expected)
            await MainActor.run {
                switch outcome {
                case .success(let proposals, _):
                    draft.loadProposals(proposals, endID: currentEndID)
                    detectionState = .idle
                case .lowConfidence(let reason):
                    // Manual fallback: keep whatever is already in the draft.
                    detectionState = .failed(reason)
                }
            }
        }
    }

    private func confirmEnd() {
        let confirmed = draft.confirm()
        guard !confirmed.isEmpty else { return }
        if state.confirmEnd(session: session, endIndex: endCounter, confirmedImpacts: confirmed, endID: endID) {
            endCounter += 1
            endID = UUID()
            selectedImpactID = nil
        } else {
            // Save failed: restore the draft so nothing is lost.
            draft = ScoringDraft(impacts: confirmed.map {
                var copy = $0
                copy.confirmed = false
                return copy
            })
        }
    }
}
