import XCTest
@testable import ArrowTuneCore

final class StoreAndPolicyTests: XCTestCase {
    private func makeSession(id: UUID = UUID()) -> Session {
        Session(sessionID: id, date: Date(timeIntervalSince1970: 1_700_000_000),
                bowType: .recurve, distanceM: 30, targetFace: .full60cm, arrowsPerEnd: 6)
    }

    func testPersistenceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("store.json")
        let store = LocalStore(fileURL: url)
        let session = makeSession()
        let end = End(sessionID: session.sessionID, endIndex: 1, scoreTotal: 52)
        let impact = ArrowImpact(endID: end.endID, xNorm: 0.1, yNorm: 0.1, ringValue: 9, source: .manual, confirmed: true)
        let gear = GearSetup(name: "ILF Rig", bowType: .recurve, limbSpec: "36#", arrowSpec: "ACE 520")
        let change = TuningChange(gearID: gear.gearID, component: "Plunger", fromValue: "5.0", toValue: "5.5")
        var snapshot = StoreSnapshot(sessions: [session], ends: [end], impacts: [impact],
                                     gear: [gear], tuningChanges: [change],
                                     reports: [try DiagnosisEngine.report(sessionID: session.sessionID, impacts: [impact, impact])])
        try store.save(snapshot)
        let loaded = try store.load()
        XCTAssertEqual(loaded, snapshot)
    }

    func testSaveFailureSurfacesTypedErrorAndKeepsDraft() {
        let store = MemoryStore()
        store.simulateSaveFailure = true
        let session = makeSession()
        var snapshot = store.snapshot
        snapshot.sessions.append(session)
        XCTAssertThrowsError(try store.save(snapshot)) { error in
            XCTAssertEqual(error as? StoreError, .saveFailed)
        }
        // Failed save leaves the store untouched so the form data survives.
        XCTAssertTrue(store.snapshot.sessions.isEmpty)
    }

    func testCascadeDeleteRemovesSessionChildren() {
        var snapshot = StoreSnapshot()
        let session = makeSession()
        let end = End(sessionID: session.sessionID, endIndex: 1)
        let impact = ArrowImpact(endID: end.endID, xNorm: 0, yNorm: 0, ringValue: 10, source: .photo, confirmed: true)
        let report = DiagnosisReport(sessionID: session.sessionID, centerOffsetX: 0, centerOffsetY: 0,
                                     densityRadius: 0.1, spreadH: 0.1, spreadV: 0.1,
                                     patternLabel: "tight group", confidence: 0.9)
        snapshot.sessions = [session]
        snapshot.ends = [end]
        snapshot.impacts = [impact]
        snapshot.reports = [report]
        // Cascade: session deletion removes its ends, impacts, and reports.
        snapshot.sessions.removeAll { $0.sessionID == session.sessionID }
        let orphanEndIDs = Set(snapshot.ends.filter { $0.sessionID == session.sessionID }.map(\.endID))
        snapshot.ends.removeAll { $0.sessionID == session.sessionID }
        snapshot.impacts.removeAll { orphanEndIDs.contains($0.endID) }
        snapshot.reports.removeAll { $0.sessionID == session.sessionID }
        XCTAssertTrue(snapshot.sessions.isEmpty)
        XCTAssertTrue(snapshot.ends.isEmpty)
        XCTAssertTrue(snapshot.impacts.isEmpty)
        XCTAssertTrue(snapshot.reports.isEmpty)
    }

    func testFreeTierAllowsFirstGearBlocksSecond() {
        XCTAssertTrue(FreeTierPolicy.canCreateGear(existingCount: 0, isPro: false))
        XCTAssertFalse(FreeTierPolicy.canCreateGear(existingCount: 1, isPro: false))
        XCTAssertTrue(FreeTierPolicy.canCreateGear(existingCount: 1, isPro: true))
        XCTAssertTrue(FreeTierPolicy.canCreateGear(existingCount: 9, isPro: true))
    }

    func testFreeTierGatesExportAndMultiGearCompare() {
        XCTAssertFalse(FreeTierPolicy.canExport(isPro: false))
        XCTAssertTrue(FreeTierPolicy.canExport(isPro: true))
        XCTAssertTrue(FreeTierPolicy.canCompareMultipleGear(selectedGearCount: 1, isPro: false))
        XCTAssertFalse(FreeTierPolicy.canCompareMultipleGear(selectedGearCount: 2, isPro: false))
        XCTAssertTrue(FreeTierPolicy.canCompareMultipleGear(selectedGearCount: 3, isPro: true))
    }

    func testExportCSVContainsConfirmedImpactsOnly() throws {
        let session = makeSession()
        let end = End(sessionID: session.sessionID, endIndex: 1)
        let confirmed = ArrowImpact(endID: end.endID, xNorm: 0.1, yNorm: 0.1, ringValue: 9, source: .photo, confirmed: true)
        let draft = ArrowImpact(endID: end.endID, xNorm: 0.2, yNorm: 0.2, ringValue: 8, source: .photo, confirmed: false)
        let snapshot = StoreSnapshot(sessions: [session], ends: [end], impacts: [confirmed, draft])
        let csv = DataExporter.exportCSV(snapshot)
        let rows = csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 2, "header plus exactly the one confirmed impact")
        XCTAssertTrue(rows[1].contains("9"))
        let json = try DataExporter.exportJSON(snapshot)
        XCTAssertFalse(json.isEmpty)
    }
}
