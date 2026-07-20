import SwiftUI

/// /gear/{id} — profile parameters, tuning history, delete with explicit
/// impact statement. /gear/{id}/change records one tuning event.
struct GearDetailView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let gear: GearSetup

    @State private var showsEdit = false
    @State private var showsChange = false
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    private var currentGear: GearSetup { state.gearProfile(id: gear.gearID) ?? gear }
    private var changes: [TuningChange] { state.changes(for: currentGear) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                paramsCard
                changesSection
                deleteButton
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(currentGear.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showsEdit = true }
                    .accessibilityLabel("Edit gear profile")
            }
        }
        .sheet(isPresented: $showsEdit) {
            NavigationView { GearEditView(gear: currentGear, isPresented: $showsEdit) }
                .navigationViewStyle(.stack)
                .environmentObject(state)
        }
        .sheet(isPresented: $showsChange) {
            NavigationView { TuningChangeView(gear: currentGear, isPresented: $showsChange) }
                .navigationViewStyle(.stack)
                .environmentObject(state)
        }
        .alert("Delete this gear profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: deleteGear)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its tuning change history is deleted with it. Sessions that used this gear keep their data.")
        }
        .alert("Could not delete gear profile", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not save on this device. Your gear profile and tuning history are still here — try deleting again.")
        }
    }

    private var paramsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Setup")
            paramRow("Bow type", currentGear.bowType.displayName)
            paramRow("Limbs", currentGear.limbSpec.isEmpty ? "—" : currentGear.limbSpec)
            paramRow("Arrows", currentGear.arrowSpec.isEmpty ? "—" : currentGear.arrowSpec)
            paramRow("Sight mark", currentGear.sightMark.isEmpty ? "—" : currentGear.sightMark)
            Button { showsChange = true } label: {
                Label("Record tuning change", systemImage: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.signal)
                    .foregroundColor(.white)
            }
            .padding(.top, 6)
            .accessibilityHint("Logs a before/after value change on this gear")
        }
        .padding(14)
        .background(Theme.cardGround)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
    }

    private func paramRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.inkSoft)
            Spacer()
            Text(value).foregroundColor(Theme.ink)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Tuning history")
            if changes.isEmpty {
                Text("No tuning changes recorded yet.")
                    .font(.footnote)
                    .foregroundColor(Theme.inkSoft)
            } else {
                ForEach(changes) { change in
                    HStack(spacing: 10) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.signal)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(change.component)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(Theme.ink)
                            Text("\(change.fromValue) → \(change.toValue)")
                                .font(.system(.caption, design: .monospaced).monospacedDigit())
                                .foregroundColor(Theme.signal)
                            if !change.note.isEmpty {
                                Text(change.note)
                                    .font(.caption)
                                    .foregroundColor(Theme.inkSoft)
                            }
                        }
                        Spacer()
                        Text(change.changedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption2)
                            .foregroundColor(Theme.inkSoft)
                    }
                    .padding(10)
                    .background(Theme.cardGround)
                    .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func deleteGear() {
        if state.deleteGear(currentGear) {
            dismiss()
        } else {
            deleteFailed = true
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Text("Delete gear profile")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(Theme.warn)
                .overlay(Rectangle().stroke(Theme.warn.opacity(0.5), lineWidth: 1))
        }
    }
}

/// /gear/{id}/change — event-style tuning record: component, before/after
/// values, note. Save failure keeps the form intact for retry.
struct TuningChangeView: View {
    @EnvironmentObject var state: AppState
    let gear: GearSetup
    @Binding var isPresented: Bool

    private static let components = ["Plunger", "Arrow rest", "Nocking point", "Sight", "Limbs", "Arrows", "Stabilizer", "Brace height", "Tiller", "Other"]

    @State private var component = "Plunger"
    @State private var fromValue = ""
    @State private var toValue = ""
    @State private var note = ""
    @State private var saveFailed = false

    private var formValid: Bool {
        !fromValue.trimmingCharacters(in: .whitespaces).isEmpty
            && !toValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section(header: SectionLabel(text: "Component")) {
                Picker("Component", selection: $component) {
                    ForEach(Self.components, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityLabel("Component changed")
            }
            Section(header: SectionLabel(text: "Change")) {
                TextField("From (previous value)", text: $fromValue)
                    .accessibilityLabel("Previous value")
                TextField("To (new value)", text: $toValue)
                    .accessibilityLabel("New value")
            }
            Section(header: SectionLabel(text: "Note")) {
                TextField("Why this change (optional)", text: $note)
                    .accessibilityLabel("Change note")
            }
            if saveFailed {
                Section {
                    StatusBar(kind: .failure,
                              text: "Could not save on this device. Your entries are still here — try saving again.")
                }
            }
        }
        .navigationTitle("Tuning Change")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }.disabled(!formValid)
            }
        }
    }

    private func save() {
        if state.recordChange(gear: gear, component: component,
                              fromValue: fromValue, toValue: toValue, note: note) {
            isPresented = false
        } else {
            saveFailed = true
        }
    }
}
