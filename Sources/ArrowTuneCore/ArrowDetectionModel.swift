import Foundation

/// A candidate dark blob found on a target photo, in normalized image space.
/// x/y are relative to the framing guide center; radius is relative to the
/// guide radius. `darkness` is mean inverted luminance in 0...1.
public struct DetectionCandidate: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let radius: Double
    public let darkness: Double
    /// Roundness score in 0...1 (1 = perfect circle).
    public let roundness: Double

    public init(x: Double, y: Double, radius: Double, darkness: Double, roundness: Double) {
        self.x = x
        self.y = y
        self.radius = radius
        self.darkness = darkness
        self.roundness = roundness
    }
}

public struct DetectionProposal: Equatable, Sendable {
    public let xNorm: Double
    public let yNorm: Double
    public let ringValue: Int
    public let confidence: Double
}

public enum DetectionOutcome: Equatable, Sendable {
    case success(proposals: [DetectionProposal], confidence: Double)
    /// Confidence below threshold or no plausible arrow holes found; the
    /// caller must offer the manual tap path with no data loss.
    case lowConfidence(reason: String)
}

/// Pure on-device scoring of arrow-hole candidates. The Vision glue in the
/// app target produces `DetectionCandidate` values; this model decides which
/// candidates are arrow holes and what they score. Fully deterministic and
/// unit-testable without images.
public enum ArrowDetectionModel {
    /// Minimum fraction of expected arrows that must be found for success.
    public static let minimumDetectionRatio = 0.95
    /// Aggregate confidence required to surface a proposal.
    public static let confidenceThreshold = 0.55
    /// Arrow holes are small, dark, round marks. Radii are relative to the
    /// framing guide (the scoring radius), so a hole spans a few percent.
    private static let minHoleRadius = 0.004
    private static let maxHoleRadius = 0.06
    private static let minDarkness = 0.35
    private static let minRoundness = 0.45

    public static func detect(
        candidates: [DetectionCandidate],
        expectedArrows: Int
    ) -> DetectionOutcome {
        guard expectedArrows > 0 else {
            return .lowConfidence(reason: "No arrows expected for this end")
        }
        let holes = candidates.filter { candidate in
            candidate.radius >= minHoleRadius
                && candidate.radius <= maxHoleRadius
                && candidate.darkness >= minDarkness
                && candidate.roundness >= minRoundness
                && (candidate.x * candidate.x + candidate.y * candidate.y).squareRoot() <= 1.02
        }
        // Merge near-duplicate candidates (same hole seen twice).
        let merged = mergeDuplicates(holes)
        guard !merged.isEmpty else {
            return .lowConfidence(reason: "No arrow holes could be isolated on the target")
        }
        let ratio = Double(merged.count) / Double(expectedArrows)
        guard ratio >= minimumDetectionRatio else {
            return .lowConfidence(
                reason: "Only \(merged.count) of \(expectedArrows) arrows could be read"
            )
        }
        let proposals = merged.map { hole -> DetectionProposal in
            let confidence = holeConfidence(hole)
            return DetectionProposal(
                xNorm: hole.x,
                yNorm: hole.y,
                ringValue: RingScoring.ringValue(xNorm: hole.x, yNorm: hole.y),
                confidence: confidence
            )
        }
        let aggregate = proposals.map(\.confidence).reduce(0, +) / Double(proposals.count)
        guard aggregate >= confidenceThreshold else {
            return .lowConfidence(reason: "Photo contrast is too low for a reliable read")
        }
        return .success(proposals: proposals, confidence: aggregate)
    }

    private static func holeConfidence(_ hole: DetectionCandidate) -> Double {
        max(0.0, min(1.0, 0.45 * hole.darkness + 0.45 * hole.roundness + 0.1))
    }

    private static func mergeDuplicates(_ holes: [DetectionCandidate]) -> [DetectionCandidate] {
        // Same-hole echoes jitter by a fraction of the hole radius, while
        // distinct arrows in a tight group can land within one radius of each
        // other. Merge only near-concentric echoes (under half the smaller
        // radius) and keep the darker reading.
        var kept: [DetectionCandidate] = []
        for hole in holes.sorted(by: { $0.darkness > $1.darkness }) {
            let duplicate = kept.contains { other in
                let dx = hole.x - other.x
                let dy = hole.y - other.y
                return (dx * dx + dy * dy).squareRoot() < 0.5 * min(hole.radius, other.radius)
            }
            if !duplicate { kept.append(hole) }
        }
        return kept
    }
}
