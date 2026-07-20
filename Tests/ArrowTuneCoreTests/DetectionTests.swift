import XCTest
@testable import ArrowTuneCore

/// Deterministic RNG so the synthetic sample set is reproducible.
private struct LCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 11) & 0x1FFFFFFFFFFFFF) / Double(0x20000000000000)
    }
}

/// REQ-AI-01 test evidence: a synthetic set of 20 standard 40cm/60cm target
/// samples. Each sample plants six known arrow impacts plus realistic noise
/// blobs (dust, folds, shadows) and asserts the on-device detection model
/// recovers >=95% of arrows with a ring error of at most one ring.
final class DetectionTests: XCTestCase {
    private struct Sample {
        let face: TargetFace
        let truths: [(x: Double, y: Double)]
        let candidates: [DetectionCandidate]
    }

    private func makeSample(index: Int) -> Sample {
        var rng = LCG(seed: UInt64(1000 &+ index))
        let face: TargetFace = index % 2 == 0 ? .full40cm : .full60cm
        var truths: [(Double, Double)] = []
        var candidates: [DetectionCandidate] = []
        // Six true arrow holes, clustered loosely around a random center.
        let groupCX = (rng.next() - 0.5) * 0.4
        let groupCY = (rng.next() - 0.5) * 0.4
        for _ in 0..<6 {
            let x = groupCX + (rng.next() - 0.5) * 0.35
            let y = groupCY + (rng.next() - 0.5) * 0.35
            let r = (x * x + y * y).squareRoot()
            let clamped = r > 0.98 ? (x / r * 0.98, y / r * 0.98) : (x, y)
            truths.append(clamped)
            // Vision sees the hole with sub-pixel jitter and strong signal.
            candidates.append(DetectionCandidate(
                x: clamped.0 + (rng.next() - 0.5) * 0.01,
                y: clamped.1 + (rng.next() - 0.5) * 0.01,
                radius: 0.012 + rng.next() * 0.01,
                darkness: 0.55 + rng.next() * 0.35,
                roundness: 0.6 + rng.next() * 0.35
            ))
        }
        // Noise: paper dust (too small), target fold (too large), shadow
        // (too light), print speck (not round), smudge far off-face.
        let noiseCount = 2 + Int(rng.next() * 3)
        for _ in 0..<noiseCount {
            let pick = rng.next()
            if pick < 0.25 {
                candidates.append(DetectionCandidate(x: rng.next() - 0.5, y: rng.next() - 0.5, radius: 0.002, darkness: 0.9, roundness: 0.9))
            } else if pick < 0.5 {
                candidates.append(DetectionCandidate(x: rng.next() - 0.5, y: rng.next() - 0.5, radius: 0.09, darkness: 0.9, roundness: 0.9))
            } else if pick < 0.75 {
                candidates.append(DetectionCandidate(x: rng.next() - 0.5, y: rng.next() - 0.5, radius: 0.02, darkness: 0.2, roundness: 0.9))
            } else {
                candidates.append(DetectionCandidate(x: rng.next() - 0.5, y: rng.next() - 0.5, radius: 0.02, darkness: 0.8, roundness: 0.2))
            }
        }
        return Sample(face: face, truths: truths, candidates: candidates)
    }

    func testTwentyStandardSamplesMeetDetectionBar() {
        var totalDetected = 0
        var totalExpected = 0
        var maxRingError = 0
        for index in 0..<20 {
            let sample = makeSample(index: index)
            let outcome = ArrowDetectionModel.detect(candidates: sample.candidates, expectedArrows: sample.truths.count)
            guard case .success(let proposals, _) = outcome else {
                XCTFail("sample \(index) failed detection: \(outcome)")
                continue
            }
            totalExpected += sample.truths.count
            var matched: [(truth: (x: Double, y: Double), proposal: DetectionProposal)] = []
            for truth in sample.truths {
                guard let nearest = proposals.min(by: {
                    let d0 = (($0.xNorm - truth.x) * ($0.xNorm - truth.x) + ($0.yNorm - truth.y) * ($0.yNorm - truth.y)).squareRoot()
                    let d1 = (($1.xNorm - truth.x) * ($1.xNorm - truth.x) + ($1.yNorm - truth.y) * ($1.yNorm - truth.y)).squareRoot()
                    return d0 < d1
                }) else { continue }
                let distance = ((nearest.xNorm - truth.x) * (nearest.xNorm - truth.x)
                    + (nearest.yNorm - truth.y) * (nearest.yNorm - truth.y)).squareRoot()
                if distance < 0.05 {
                    matched.append((truth, nearest))
                }
            }
            totalDetected += matched.count
            for (truth, proposal) in matched {
                let expectedRing = RingScoring.ringValue(xNorm: truth.x, yNorm: truth.y)
                maxRingError = max(maxRingError, abs(proposal.ringValue - expectedRing))
            }
        }
        let detectionRate = Double(totalDetected) / Double(totalExpected)
        XCTAssertGreaterThanOrEqual(detectionRate, 0.95, "detection rate \(detectionRate) below 95% bar")
        XCTAssertLessThanOrEqual(maxRingError, 1, "ring error \(maxRingError) exceeds one ring")
    }

    func testBacklitLowContrastPhotoFallsBackToManual() {
        // All candidates faint and washed out: detection must refuse.
        let candidates = (0..<6).map { i in
            DetectionCandidate(x: Double(i) * 0.1 - 0.25, y: 0.05, radius: 0.015, darkness: 0.18, roundness: 0.4)
        }
        let outcome = ArrowDetectionModel.detect(candidates: candidates, expectedArrows: 6)
        guard case .lowConfidence(let reason) = outcome else {
            return XCTFail("expected lowConfidence, got \(outcome)")
        }
        XCTAssertFalse(reason.isEmpty)
    }

    func testPartialReadBelowRatioFallsBack() {
        // Only 4 of 6 arrows readable.
        let candidates = (0..<4).map { i in
            DetectionCandidate(x: Double(i) * 0.1 - 0.15, y: 0.1, radius: 0.015, darkness: 0.8, roundness: 0.8)
        }
        let outcome = ArrowDetectionModel.detect(candidates: candidates, expectedArrows: 6)
        guard case .lowConfidence = outcome else {
            return XCTFail("expected lowConfidence for partial read, got \(outcome)")
        }
    }

    func testDuplicateContoursMergeIntoOneHole() {
        let hole = DetectionCandidate(x: 0.2, y: 0.2, radius: 0.015, darkness: 0.9, roundness: 0.9)
        let echo = DetectionCandidate(x: 0.205, y: 0.198, radius: 0.014, darkness: 0.6, roundness: 0.8)
        var candidates = [hole, echo]
        for i in 0..<5 {
            candidates.append(DetectionCandidate(x: -0.3 + Double(i) * 0.1, y: -0.2, radius: 0.015, darkness: 0.8, roundness: 0.85))
        }
        let outcome = ArrowDetectionModel.detect(candidates: candidates, expectedArrows: 6)
        guard case .success(let proposals, _) = outcome else {
            return XCTFail("expected success, got \(outcome)")
        }
        XCTAssertEqual(proposals.count, 6)
    }
}
