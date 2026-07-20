import Foundation

/// Draft impacts for one end under review. Nothing here is persisted: the
/// store only ever receives confirmed impacts via `confirm(into:)`.
public struct ScoringDraft: Equatable, Sendable {
    public private(set) var impacts: [ArrowImpact]

    public init(impacts: [ArrowImpact] = []) {
        self.impacts = impacts.filter { !$0.confirmed }
    }

    /// Replaces the draft with detection proposals (still unconfirmed).
    public mutating func loadProposals(_ proposals: [DetectionProposal], endID: UUID) {
        impacts = proposals.map {
            ArrowImpact(
                endID: endID,
                xNorm: $0.xNorm,
                yNorm: $0.yNorm,
                ringValue: $0.ringValue,
                source: .photo,
                confirmed: false
            )
        }
    }

    /// Manual tap entry: capability-equivalent to the photo path.
    public mutating func addManualImpact(xNorm: Double, yNorm: Double, endID: UUID) {
        impacts.append(
            ArrowImpact(
                endID: endID,
                xNorm: xNorm,
                yNorm: yNorm,
                ringValue: RingScoring.ringValue(xNorm: xNorm, yNorm: yNorm),
                source: .manual,
                confirmed: false
            )
        )
    }

    public mutating func moveImpact(id: UUID, toX xNorm: Double, toY yNorm: Double) {
        guard let index = impacts.firstIndex(where: { $0.impactID == id }) else { return }
        impacts[index].xNorm = xNorm
        impacts[index].yNorm = yNorm
        impacts[index].ringValue = RingScoring.ringValue(xNorm: xNorm, yNorm: yNorm)
    }

    public mutating func removeImpact(id: UUID) {
        impacts.removeAll { $0.impactID == id }
    }

    public var scoreTotal: Int { impacts.map(\.ringValue).reduce(0, +) }

    /// Confirmation gate: the only path that produces persisted impacts.
    /// Returns impacts marked confirmed; the draft resets for the next end.
    public mutating func confirm() -> [ArrowImpact] {
        let confirmed = impacts.map { impact -> ArrowImpact in
            var copy = impact
            copy.confirmed = true
            return copy
        }
        impacts = []
        return confirmed
    }

    /// Discards the draft without writing anything.
    public mutating func discard() {
        impacts = []
    }
}
