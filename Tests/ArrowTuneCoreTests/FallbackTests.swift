import XCTest
@testable import ArrowTuneCore

/// REQ-AI-03 test evidence: when detection fails or the device is offline,
/// the manual tap path completes the end with capability equal to the photo
/// path, and impacts already recorded for the session are preserved.
final class FallbackTests: XCTestCase {
    private let endID = UUID()

    func testManualPathCompletesFullEndWithoutModel() {
        var draft = ScoringDraft()
        // Detection failed: user taps six impacts manually.
        let taps = [(0.05, 0.1), (0.12, 0.02), (-0.03, 0.15), (0.2, -0.05), (0.0, 0.0), (0.09, 0.11)]
        for tap in taps {
            draft.addManualImpact(xNorm: tap.0, yNorm: tap.1, endID: endID)
        }
        XCTAssertEqual(draft.impacts.count, 6)
        XCTAssertTrue(draft.impacts.allSatisfy { $0.source == .manual })
        // Manual path scores through the same ring mapping as photo path.
        XCTAssertEqual(draft.impacts.map(\.ringValue), taps.map { RingScoring.ringValue(xNorm: $0.0, yNorm: $0.1) })
        let written = draft.confirm()
        XCTAssertEqual(written.count, 6)
        XCTAssertTrue(written.allSatisfy { $0.confirmed })
    }

    func testFailedDetectionPreservesPreviouslyConfirmedImpacts() {
        let store = MemoryStore()
        // End 1 already confirmed and persisted.
        var firstDraft = ScoringDraft()
        firstDraft.addManualImpact(xNorm: 0.1, yNorm: 0.1, endID: endID)
        firstDraft.addManualImpact(xNorm: 0.2, yNorm: 0.0, endID: endID)
        var snapshot = store.snapshot
        snapshot.impacts.append(contentsOf: firstDraft.confirm())
        try! store.save(snapshot)
        let persistedBefore = store.snapshot.impacts.count

        // End 2: detection fails (backlit photo), user goes manual.
        let faint = (0..<6).map { i in
            DetectionCandidate(x: Double(i) * 0.08 - 0.2, y: 0.02, radius: 0.015, darkness: 0.1, roundness: 0.3)
        }
        guard case .lowConfidence = ArrowDetectionModel.detect(candidates: faint, expectedArrows: 6) else {
            return XCTFail("expected detection failure for faint photo")
        }
        var secondDraft = ScoringDraft()
        for i in 0..<6 {
            secondDraft.addManualImpact(xNorm: Double(i) * 0.05, yNorm: 0.05, endID: UUID())
        }
        snapshot = store.snapshot
        snapshot.impacts.append(contentsOf: secondDraft.confirm())
        try! store.save(snapshot)

        XCTAssertEqual(store.snapshot.impacts.count, persistedBefore + 6, "failed detection must not drop earlier data")
    }

    func testMixedPhotoAndManualDraftIsEditableUntilConfirm() {
        var draft = ScoringDraft()
        draft.loadProposals([
            DetectionProposal(xNorm: 0.1, yNorm: 0.1, ringValue: 9, confidence: 0.9),
            DetectionProposal(xNorm: 0.15, yNorm: 0.05, ringValue: 9, confidence: 0.85),
        ], endID: endID)
        // User deletes a misread proposal and taps the missing arrow manually.
        draft.removeImpact(id: draft.impacts[1].impactID)
        draft.addManualImpact(xNorm: 0.2, yNorm: 0.2, endID: endID)
        let written = draft.confirm()
        XCTAssertEqual(written.count, 2)
        XCTAssertEqual(Set(written.map(\.source)), [.photo, .manual])
    }
}
