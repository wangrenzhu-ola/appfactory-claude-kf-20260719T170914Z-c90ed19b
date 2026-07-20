import Foundation
import SwiftUI

/// Central application state: one local snapshot, one store, one entitlement.
/// Zero account, zero network for data: everything persists to an on-device
/// JSON document via LocalStore. All mutations go through methods here so a
/// failed save surfaces an inline error while the in-memory form data stays.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: StoreSnapshot
    @Published var lastError: String?
    @Published var lastNotice: String?
    @Published var storeAvailable = true

    let store: LocalStore
    let pro: ProStore

    init(store: LocalStore? = nil, pro: ProStore? = nil) {
        let resolvedStore = store ?? AppState.makeDefaultStore()
        self.store = resolvedStore
        self.pro = pro ?? ProStore()
        var loaded = StoreSnapshot.empty
        do {
            loaded = try resolvedStore.load()
        } catch {
            self.lastError = "Saved data could not be read. You can keep using the app; new entries are still saved on this device."
        }
        self.snapshot = loaded
    }

    private static func makeDefaultStore() -> LocalStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return LocalStore(fileURL: base.appendingPathComponent("ArrowTune/store.json"))
    }

    // MARK: - Persistence

    /// Saves the current snapshot. On failure the in-memory snapshot is kept
    /// (nothing the user entered is lost) and an en-US inline error surfaces.
    @discardableResult
    private func persist(notice: String?) -> Bool {
        do {
            try store.save(snapshot)
            storeAvailable = true
            if let notice { lastNotice = notice }
            return true
        } catch {
            storeAvailable = false
            lastError = "Could not save on this device. Your entries are still here — try saving again."
            return false
        }
    }

    func dismissError() { lastError = nil }
    func dismissNotice() { lastNotice = nil }

    // MARK: - Sessions

    var sessions: [Session] { snapshot.sessions.sorted { $0.date > $1.date } }

    @discardableResult
    func createSession(bowType: BowType, distanceM: Int, face: TargetFace, arrowsPerEnd: Int, note: String, gearID: UUID?) -> Session? {
        let session = Session(bowType: bowType, distanceM: distanceM, targetFace: face,
                              arrowsPerEnd: arrowsPerEnd, note: note, gearID: gearID)
        snapshot.sessions.append(session)
        guard persist(notice: nil) else {
            snapshot.sessions.removeAll { $0.sessionID == session.sessionID }
            return nil
        }
        return session
    }

    /// Cascading delete: the session's ends, impacts, and diagnosis reports go
    /// with it. Gear profiles and tuning history are not touched.
    func deleteSession(_ session: Session) {
        let endIDs = Set(snapshot.ends.filter { $0.sessionID == session.sessionID }.map(\.endID))
        snapshot.sessions.removeAll { $0.sessionID == session.sessionID }
        snapshot.ends.removeAll { $0.sessionID == session.sessionID }
        snapshot.impacts.removeAll { endIDs.contains($0.endID) }
        snapshot.reports.removeAll { $0.sessionID == session.sessionID }
        _ = persist(notice: "Session deleted")
    }

    func session(id: UUID?) -> Session? {
        snapshot.sessions.first { $0.sessionID == id }
    }

    func ends(for session: Session) -> [End] {
        snapshot.ends.filter { $0.sessionID == session.sessionID }.sorted { $0.endIndex < $1.endIndex }
    }

    func impacts(for end: End) -> [ArrowImpact] {
        snapshot.impacts.filter { $0.endID == end.endID }
    }

    func confirmedImpacts(for session: Session) -> [ArrowImpact] {
        let endIDs = Set(snapshot.ends.filter { $0.sessionID == session.sessionID }.map(\.endID))
        return snapshot.impacts.filter { endIDs.contains($0.endID) && $0.confirmed }
    }

    func latestReport(for session: Session) -> DiagnosisReport? {
        snapshot.reports
            .filter { $0.sessionID == session.sessionID }
            .sorted { ($0.confirmedAt ?? .distantPast) > ($1.confirmedAt ?? .distantPast) }
            .first
    }

    /// Confirms one end's draft impacts: writes impacts, upserts the end total,
    /// and marks the previously confirmed diagnosis for this session stale by
    /// leaving it untouched (a fresh one can be confirmed from the group view).
    @discardableResult
    func confirmEnd(session: Session, endIndex: Int, confirmedImpacts: [ArrowImpact], endID: UUID) -> Bool {
        var end = snapshot.ends.first { $0.endID == endID }
            ?? End(endID: endID, sessionID: session.sessionID, endIndex: endIndex)
        end.scoreTotal = confirmedImpacts.map(\.ringValue).reduce(0, +)
        if snapshot.ends.contains(where: { $0.endID == end.endID }) {
            snapshot.impacts.removeAll { $0.endID == end.endID }
            snapshot.ends.removeAll { $0.endID == end.endID }
        }
        snapshot.ends.append(end)
        snapshot.impacts.append(contentsOf: confirmedImpacts)
        return persist(notice: "End \(endIndex) saved — \(end.scoreTotal) points")
    }

    // MARK: - Diagnosis

    /// Live, unpersisted diagnosis for review. Nothing here is written until
    /// the user confirms on the diagnosis screen (confirmation-before-write).
    func draftDiagnosis(for session: Session) -> Diagnosis? {
        let impacts = confirmedImpacts(for: session)
        guard let metrics = try? GroupMetricsCalculator.metrics(for: impacts) else { return nil }
        return DiagnosisEngine.diagnose(metrics: metrics)
    }

    func draftMetrics(for session: Session) -> GroupMetrics? {
        try? GroupMetricsCalculator.metrics(for: confirmedImpacts(for: session))
    }

    @discardableResult
    func confirmDiagnosis(session: Session, note: String) -> Bool {
        let impacts = confirmedImpacts(for: session)
        guard var report = try? DiagnosisEngine.report(sessionID: session.sessionID, impacts: impacts) else {
            return false
        }
        report.userNote = note
        report.confirmedAt = Date()
        snapshot.reports.removeAll { $0.sessionID == session.sessionID }
        snapshot.reports.append(report)
        return persist(notice: "Diagnosis saved")
    }

    // MARK: - Gear

    var gear: [GearSetup] { snapshot.gear.sorted { $0.createdAt < $1.createdAt } }

    func gearProfile(id: UUID?) -> GearSetup? {
        snapshot.gear.first { $0.gearID == id }
    }

    var canCreateGear: Bool {
        FreeTierPolicy.canCreateGear(existingCount: snapshot.gear.count, isPro: pro.isPro)
    }

    @discardableResult
    func createGear(name: String, bowType: BowType, limbSpec: String, arrowSpec: String, sightMark: String) -> GearSetup? {
        guard canCreateGear else { return nil }
        let gear = GearSetup(name: name, bowType: bowType, limbSpec: limbSpec, arrowSpec: arrowSpec, sightMark: sightMark)
        snapshot.gear.append(gear)
        guard persist(notice: "Gear profile saved") else {
            snapshot.gear.removeAll { $0.gearID == gear.gearID }
            return nil
        }
        return gear
    }

    @discardableResult
    func updateGear(_ gear: GearSetup) -> Bool {
        guard let index = snapshot.gear.firstIndex(where: { $0.gearID == gear.gearID }) else { return false }
        snapshot.gear[index] = gear
        return persist(notice: "Gear profile updated")
    }

    /// Deletes the gear profile. Sessions that referenced it keep their data;
    /// its tuning events are removed with the profile.
    func deleteGear(_ gear: GearSetup) {
        snapshot.gear.removeAll { $0.gearID == gear.gearID }
        snapshot.tuningChanges.removeAll { $0.gearID == gear.gearID }
        for index in snapshot.sessions.indices where snapshot.sessions[index].gearID == gear.gearID {
            snapshot.sessions[index].gearID = nil
        }
        _ = persist(notice: "Gear profile deleted")
    }

    func changes(for gear: GearSetup) -> [TuningChange] {
        snapshot.tuningChanges.filter { $0.gearID == gear.gearID }.sorted { $0.changedAt > $1.changedAt }
    }

    @discardableResult
    func recordChange(gear: GearSetup, component: String, fromValue: String, toValue: String, note: String) -> Bool {
        let change = TuningChange(gearID: gear.gearID, component: component,
                                  fromValue: fromValue, toValue: toValue, note: note)
        snapshot.tuningChanges.append(change)
        guard persist(notice: "Tuning change saved") else {
            snapshot.tuningChanges.removeAll { $0.changeID == change.changeID }
            return false
        }
        return true
    }

    // MARK: - Attribution

    /// Alignment entries for the timeline, optionally filtered to one gear.
    func attributionEntries(gearID: UUID?) -> [AttributionEntry] {
        let changes = snapshot.tuningChanges
            .filter { gearID == nil || $0.gearID == gearID }
        let reports = snapshot.reports.filter { report in
            guard gearID != nil else { return true }
            return session(id: report.sessionID)?.gearID == gearID
        }
        let dates = Dictionary(uniqueKeysWithValues: snapshot.sessions.map { ($0.sessionID, $0.date) })
        return AttributionTimeline.align(changes: changes, reports: reports, reportDates: dates)
    }

    /// Confirmed report series for the metric line, oldest first.
    func reportSeries(gearID: UUID?) -> [(date: Date, report: DiagnosisReport)] {
        snapshot.reports
            .filter { report in
                guard gearID != nil else { return true }
                return session(id: report.sessionID)?.gearID == gearID
            }
            .compactMap { report in
                session(id: report.sessionID).map { ($0.date, report) }
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Export (Pro)

    func exportJSONData() throws -> Data { try DataExporter.exportJSON(snapshot) }
    func exportCSVText() -> String { DataExporter.exportCSV(snapshot) }
}
