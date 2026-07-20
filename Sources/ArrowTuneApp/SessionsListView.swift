import SwiftUI

/// /sessions — training session list with empty-state guidance, group summary
/// badges, and swipe-to-delete with an explicit cascade confirmation.
struct SessionsListView: View {
    @EnvironmentObject var state: AppState
    @State private var pendingDelete: Session?
    @State private var showsNewSession = false

    var body: some View {
        Group {
            if state.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showsNewSession = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New session")
            }
        }
        .sheet(isPresented: $showsNewSession) {
            NavigationView { NewSessionView(isPresented: $showsNewSession) }
                .navigationViewStyle(.stack)
                .environmentObject(state)
        }
        .alert(item: $pendingDelete) { session in
            Alert(
                title: Text("Delete this session?"),
                message: Text("Its ends, arrow impacts, and diagnosis reports are deleted with it and cannot be recovered."),
                primaryButton: .destructive(Text("Delete")) {
                    state.deleteSession(session)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private var sessionList: some View {
        List {
            ForEach(state.sessions) { session in
                NavigationLink(destination: ScoringView(session: session)) {
                    SessionCard(session: session)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = session } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    /// vis-empty-quiver: product illustration for the empty session state.
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("vis-empty-quiver")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)
            Text("No sessions yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(Theme.ink)
            Text("Log a practice session, plot each arrow, and let the group shape tell you what your last tuning change actually did.")
                .font(.subheadline)
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showsNewSession = true } label: {
                Text("New Session")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.ink)
                    .foregroundColor(.white)
            }
            .accessibilityHint("Creates a new practice session")
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

struct SessionCard: View {
    @EnvironmentObject var state: AppState
    let session: Session

    private var report: DiagnosisReport? { state.latestReport(for: session) }
    private var arrowCount: Int { state.confirmedImpacts(for: session).count }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.date, style: .date)
                    .font(.headline)
                    .foregroundColor(Theme.ink)
                Text("\(session.distanceM) m · \(session.targetFace.displayName) · \(arrowCount) arrows")
                    .font(.caption)
                    .foregroundColor(Theme.inkSoft)
            }
            Spacer()
            if let report {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.1f cm", reportOffsetCm(report)))
                        .font(.system(.callout, design: .monospaced).monospacedDigit())
                        .foregroundColor(Theme.signal)
                    Text("center offset")
                        .font(.caption2)
                        .foregroundColor(Theme.inkSoft)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: "Group center offset %.1f centimeters", reportOffsetCm(report)))
            } else {
                Text("No diagnosis")
                    .font(.caption2)
                    .foregroundColor(Theme.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }

    private func reportOffsetCm(_ report: DiagnosisReport) -> Double {
        let magnitude = (report.centerOffsetX * report.centerOffsetX
            + report.centerOffsetY * report.centerOffsetY).squareRoot()
        return magnitude * session.targetFace.scoringRadiusCm
    }
}
