import SwiftUI

/// /session/new — create a practice session. Inline validation enables Save
/// only when required fields are complete; a failed save keeps every entry.
struct NewSessionView: View {
    @EnvironmentObject var state: AppState
    @Binding var isPresented: Bool

    @State private var bowType: BowType = .recurve
    @State private var distanceText = "30"
    @State private var face: TargetFace = .full60cm
    @State private var arrowsPerEnd = 6
    @State private var note = ""
    @State private var gearID: UUID?
    @State private var created: Session?
    @State private var saveFailed = false

    private var distance: Int? { Int(distanceText).flatMap { (1...200).contains($0) ? $0 : nil } }
    private var formValid: Bool { distance != nil }

    var body: some View {
        Form {
            Section(header: SectionLabel(text: "Setup")) {
                Picker("Bow type", selection: $bowType) {
                    ForEach(BowType.allCases) { Text($0.displayName).tag($0) }
                }
                .accessibilityLabel("Bow type")
                Picker("Target face", selection: $face) {
                    ForEach(TargetFace.allCases) { Text($0.displayName).tag($0) }
                }
                .accessibilityLabel("Target face")
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("Meters", text: $distanceText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .accessibilityLabel("Distance in meters")
                    Text("m").foregroundColor(Theme.inkSoft)
                }
                if distance == nil {
                    Text("Enter a distance between 1 and 200 meters.")
                        .font(.caption)
                        .foregroundColor(Theme.warn)
                }
                Stepper("Arrows per end: \(arrowsPerEnd)", value: $arrowsPerEnd, in: 1...12)
                    .accessibilityLabel("Arrows per end")
                    .accessibilityValue("\(arrowsPerEnd)")
            }
            Section(header: SectionLabel(text: "Gear")) {
                Picker("Gear profile", selection: $gearID) {
                    Text("None").tag(UUID?.none)
                    ForEach(state.gear) { gear in
                        Text(gear.name).tag(UUID?.some(gear.gearID))
                    }
                }
                .accessibilityLabel("Gear profile used in this session")
            }
            Section(header: SectionLabel(text: "Note")) {
                TextField("Optional session note", text: $note)
                    .accessibilityLabel("Optional session note")
            }
            if saveFailed {
                Section {
                    StatusBar(kind: .failure,
                              text: "Could not save on this device. Your entries are still here — try saving again.")
                }
            }
        }
        .navigationTitle("New Session")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .disabled(!formValid)
                    .accessibilityHint(formValid ? "Saves the session and opens scoring" : "Complete the required fields first")
            }
        }
        .sheet(item: $created) { session in
            NavigationView { ScoringView(session: session, autoStartEnd: true) }
                .navigationViewStyle(.stack)
                .environmentObject(state)
        }
    }

    private func save() {
        guard let distance else { return }
        if let session = state.createSession(bowType: bowType, distanceM: distance, face: face,
                                             arrowsPerEnd: arrowsPerEnd, note: note, gearID: gearID) {
            saveFailed = false
            created = session
        } else {
            saveFailed = true
        }
    }
}
