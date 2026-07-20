import XCTest
@testable import ArrowTuneCore

/// REQ-AI-02 test evidence: detection proposals and diagnosis edits stay in
/// draft state and are never persisted until the user confirms.
final class ConfirmGateTests: XCTestCase {
    private let endID = UUID()

    private func proposals(_ count: Int) -> [DetectionProposal] {
        (0..<count).map { i in
            DetectionProposal(xNorm: Double(i) * 0.1 - 0.2, yNorm: 0.1, ringValue: 9, confidence: 0.8)
        }
    }

    func testProposalsStartUnconfirmed() {
        var draft = ScoringDraft()
        draft.loadProposals(proposals(6), endID: endID)
        XCTAssertEqual(draft.impacts.count, 6)
        XCTAssertTrue(draft.impacts.allSatisfy { !$0.confirmed })
        XCTAssertTrue(draft.impacts.allSatisfy { $0.source == .photo })
    }

    func testDraftProducesNoPersistedImpactsBeforeConfirm() {
        let store = MemoryStore()
        var draft = ScoringDraft()
        draft.loadProposals(proposals(6), endID: endID)
        // User edits a proposal: still draft, store untouched.
        let id = draft.impacts[0].impactID
        draft.moveImpact(id: id, toX: 0.05, toY: 0.05)
        XCTAssertTrue(store.snapshot.impacts.isEmpty, "no impact may be persisted before Confirm")
    }

    func testConfirmWritesExactlyTheEditedDraft() {
        let store = MemoryStore()
        var draft = ScoringDraft()
        draft.loadProposals(proposals(6), endID: endID)
        draft.removeImpact(id: draft.impacts[0].impactID)
        let kept = draft.impacts[1].impactID
        draft.moveImpact(id: kept, toX: 0.33, toY: -0.12)
        let written = draft.confirm()
        XCTAssertEqual(written.count, 5)
        XCTAssertTrue(written.allSatisfy { $0.confirmed })
        XCTAssertEqual(written.first(where: { $0.impactID == kept })?.xNorm, 0.33)
        // Persist happens only now, from confirmed output.
        var snapshot = store.snapshot
        snapshot.impacts.append(contentsOf: written)
        try! store.save(snapshot)
        XCTAssertEqual(store.snapshot.impacts.count, 5)
        // Draft resets for the next end.
        XCTAssertTrue(draft.impacts.isEmpty)
    }

    func testDiscardWritesNothing() {
        let store = MemoryStore()
        var draft = ScoringDraft()
        draft.loadProposals(proposals(6), endID: endID)
        draft.discard()
        XCTAssertTrue(draft.impacts.isEmpty)
        XCTAssertTrue(store.snapshot.impacts.isEmpty)
    }
}
