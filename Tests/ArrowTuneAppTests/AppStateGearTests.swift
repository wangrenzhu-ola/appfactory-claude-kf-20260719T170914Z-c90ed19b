import XCTest
import ArrowTuneCore
@testable import ArrowTuneAppLogic

@MainActor
final class AppStateGearTests: XCTestCase {
    private func makeState(snapshot: StoreSnapshot = .empty) -> (AppState, LocalStore) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("store.json")
        let store = LocalStore(fileURL: url)
        try! store.save(snapshot)
        return (AppState(store: store, pro: ProStore()), store)
    }

    func testGearCreateEditDeleteAndTuningChangePersist() throws {
        let (state, store) = makeState()

        let created = try XCTUnwrap(state.createGear(
            name: "Outdoor Recurve",
            bowType: .recurve,
            limbSpec: "36# medium",
            arrowSpec: "ACE 520",
            sightMark: "38.5"
        ))
        XCTAssertEqual(try store.load().gear, [created])

        var updated = created
        updated.arrowSpec = "ACE 470"
        XCTAssertTrue(state.updateGear(updated))
        XCTAssertEqual(try store.load().gear, [updated])

        XCTAssertTrue(state.recordChange(
            gear: updated,
            component: "Arrows",
            fromValue: "ACE 520",
            toValue: "ACE 470",
            note: "Outdoor wind"
        ))
        let persistedChange = try XCTUnwrap(try store.load().tuningChanges.first)
        XCTAssertEqual(persistedChange.gearID, updated.gearID)
        XCTAssertEqual(persistedChange.component, "Arrows")
        XCTAssertEqual(persistedChange.fromValue, "ACE 520")
        XCTAssertEqual(persistedChange.toValue, "ACE 470")

        XCTAssertTrue(state.deleteGear(updated))
        XCTAssertTrue(try store.load().gear.isEmpty)
        XCTAssertTrue(try store.load().tuningChanges.isEmpty)
    }

    func testFailedGearMutationsRestorePriorSnapshot() throws {
        let gear = GearSetup(name: "Indoor Recurve", bowType: .recurve, arrowSpec: "X10 450")
        let change = TuningChange(
            gearID: gear.gearID,
            component: "Plunger",
            fromValue: "4.5",
            toValue: "5.0"
        )
        let session = Session(
            bowType: .recurve,
            distanceM: 18,
            targetFace: .full40cm,
            arrowsPerEnd: 3,
            gearID: gear.gearID
        )
        let initial = StoreSnapshot(sessions: [session], gear: [gear], tuningChanges: [change])
        let (state, store) = makeState(snapshot: initial)
        store.simulateSaveFailure = true

        var updated = gear
        updated.arrowSpec = "X10 410"
        XCTAssertFalse(state.updateGear(updated))
        XCTAssertEqual(state.gear, [gear])
        XCTAssertEqual(try store.load(), initial)

        XCTAssertFalse(state.deleteGear(gear))
        XCTAssertEqual(state.gear, [gear])
        XCTAssertEqual(state.changes(for: gear), [change])
        XCTAssertEqual(state.session(id: session.sessionID)?.gearID, gear.gearID)
        XCTAssertEqual(try store.load(), initial)
    }
}
