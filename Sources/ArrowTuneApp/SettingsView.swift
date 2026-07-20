import SwiftUI
import UniformTypeIdentifiers

/// /settings — data export (Pro), Pro unlock purchase/restore, and the
/// privacy statement. No account exists anywhere in this app.
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var pro: ProStore

    @State private var showsPaywall = false
    @State private var exportDocument: ExportDocument?
    @State private var showsExporter = false
    @State private var exportError: String?

    var body: some View {
        Form {
            Section(header: SectionLabel(text: "Pro unlock")) {
                proSection
            }
            Section(header: SectionLabel(text: "Data export")) {
                exportSection
            }
            Section(header: SectionLabel(text: "Privacy")) {
                privacySection
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showsPaywall) {
            PaywallView(trigger: .export, isPresented: $showsPaywall)
                .environmentObject(pro)
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument,
                      contentType: exportDocument?.contentType ?? .json,
                      defaultFilename: exportDocument?.filename ?? "ArrowTune") { result in
            if case .failure = result {
                exportError = "Export did not complete. Nothing was shared — try again."
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        if pro.isPro {
            StatusBar(kind: .success, text: "Pro is unlocked on this device.")
        } else {
            Text("Unlock JSON/CSV export, unlimited gear profiles, and cross-gear comparison — one-time purchase, yours permanently.")
                .font(.footnote)
                .foregroundColor(Theme.inkSoft)
            Button {
                showsPaywall = true
            } label: {
                Text(pro.displayPrice.map { "Unlock Pro — \($0) one-time" } ?? "Unlock Pro")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.signal)
                    .foregroundColor(.white)
            }
            Button("Restore purchase") {
                Task { await pro.restore() }
            }
            .foregroundColor(Theme.ink)
            .accessibilityHint("Restores a previous one-time Pro purchase")
        }
        if let error = pro.purchaseError {
            StatusBar(kind: .failure, text: error)
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if pro.isPro {
            Button {
                do {
                    let data = try state.exportJSONData()
                    exportDocument = ExportDocument(data: data, filename: "ArrowTune-export.json", contentType: .json)
                    showsExporter = true
                } catch {
                    exportError = "Export could not be prepared. Try again."
                }
            } label: {
                Label("Export all data as JSON", systemImage: "square.and.arrow.up")
            }
            .accessibilityHint("Shares a full JSON snapshot of your local data")
            Button {
                let text = state.exportCSVText()
                exportDocument = ExportDocument(data: Data(text.utf8), filename: "ArrowTune-impacts.csv", contentType: .commaSeparatedText)
                showsExporter = true
            } label: {
                Label("Export confirmed impacts as CSV", systemImage: "tablecells")
            }
            .accessibilityHint("Shares confirmed arrow impacts as CSV")
        } else {
            Button {
                showsPaywall = true
            } label: {
                Label("Export is a Pro capability", systemImage: "lock")
                    .foregroundColor(Theme.signal)
            }
            .accessibilityHint("Opens the Pro unlock options")
        }
        if let exportError {
            StatusBar(kind: .failure, text: exportError)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            privacyRow("No account", "ArrowTune never asks you to sign in. There is no account system anywhere in the app.")
            privacyRow("Photos stay on this device", "A target photo is used once, on this device, to detect arrows. The photo itself is not kept, not uploaded, and not shared. Only the arrow positions you confirm are saved.")
            privacyRow("No tracking", "The app makes no analytics or tracking calls. The only network traffic ever possible is the App Store purchase flow handled by the system.")
            privacyRow("Your data is yours", "Sessions, arrows, diagnoses, and gear live in one local document on this device. Delete the app and they are gone.")
        }
        .padding(.vertical, 4)
    }

    private func privacyRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(Theme.ink)
            Text(body).font(.footnote).foregroundColor(Theme.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shareable export payload for the system document exporter.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    let data: Data
    let filename: String
    let contentType: UTType

    init(data: Data, filename: String, contentType: UTType) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        filename = "ArrowTune"
        contentType = .json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
