import SwiftUI

/// /gear — gear profile list. Free tier holds one profile; creating beyond
/// the free limit presents the Pro paywall (no silent blocking).
struct GearListView: View {
    @EnvironmentObject var state: AppState
    @State private var showsNewGear = false
    @State private var showsPaywall = false

    var body: some View {
        Group {
            if state.gear.isEmpty {
                emptyState
            } else {
                gearList
            }
        }
        .navigationTitle("Gear")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { addGear() } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New gear profile")
            }
        }
        .sheet(isPresented: $showsNewGear) {
            NavigationView { GearEditView(gear: nil, isPresented: $showsNewGear) }
                .navigationViewStyle(.stack)
                .environmentObject(state)
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(trigger: .gearLimit, isPresented: $showsPaywall)
                .environmentObject(state.pro)
        }
    }

    private func addGear() {
        if state.canCreateGear {
            showsNewGear = true
        } else {
            showsPaywall = true
        }
    }

    private var gearList: some View {
        List {
            ForEach(state.gear) { gear in
                NavigationLink(destination: GearDetailView(gear: gear)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gear.name)
                                .font(.headline)
                                .foregroundColor(Theme.ink)
                            Text("\(gear.bowType.displayName) · \(state.changes(for: gear).count) tuning changes")
                                .font(.caption)
                                .foregroundColor(Theme.inkSoft)
                        }
                        Spacer()
                        if let last = state.changes(for: gear).first {
                            Text(last.changedAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(Theme.inkSoft)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 44))
                .foregroundColor(Theme.inkSoft)
                .accessibilityHidden(true)
            Text("No gear profiles yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(Theme.ink)
            Text("Record the setup you shoot — limbs, arrows, sight marks — so every tuning change has a home.")
                .font(.subheadline)
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { addGear() } label: {
                Text("Create your first gear profile")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.ink)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// Gear create/edit form shared by /gear/new and /gear/{id} editing.
struct GearEditView: View {
    @EnvironmentObject var state: AppState
    let gear: GearSetup?
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var bowType: BowType = .recurve
    @State private var limbSpec: String = ""
    @State private var arrowSpec: String = ""
    @State private var sightMark: String = ""
    @State private var saveFailed = false

    private var formValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section(header: SectionLabel(text: "Profile")) {
                TextField("Name (e.g. ILF rig, indoor setup)", text: $name)
                    .accessibilityLabel("Gear profile name")
                Picker("Bow type", selection: $bowType) {
                    ForEach(BowType.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section(header: SectionLabel(text: "Setup")) {
                TextField("Limb spec (e.g. 36# medium)", text: $limbSpec)
                    .accessibilityLabel("Limb specification")
                TextField("Arrow spec (e.g. ACE 520)", text: $arrowSpec)
                    .accessibilityLabel("Arrow specification")
                TextField("Sight mark", text: $sightMark)
                    .accessibilityLabel("Sight mark")
            }
            if saveFailed {
                Section {
                    StatusBar(kind: .failure,
                              text: "Could not save on this device. Your entries are still here — try saving again.")
                }
            }
        }
        .navigationTitle(gear == nil ? "New Gear" : "Edit Gear")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }.disabled(!formValid)
            }
        }
        .onAppear {
            if let gear {
                name = gear.name
                bowType = gear.bowType
                limbSpec = gear.limbSpec
                arrowSpec = gear.arrowSpec
                sightMark = gear.sightMark
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = gear {
            var updated = existing
            updated.name = trimmed
            updated.bowType = bowType
            updated.limbSpec = limbSpec
            updated.arrowSpec = arrowSpec
            updated.sightMark = sightMark
            if state.updateGear(updated) { isPresented = false } else { saveFailed = true }
        } else {
            if state.createGear(name: trimmed, bowType: bowType, limbSpec: limbSpec,
                                arrowSpec: arrowSpec, sightMark: sightMark) != nil {
                isPresented = false
            } else {
                saveFailed = true
            }
        }
    }
}
