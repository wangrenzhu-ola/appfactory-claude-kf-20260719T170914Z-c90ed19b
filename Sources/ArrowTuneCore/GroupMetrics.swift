import Foundation

/// Quantified shape of one arrow group, derived from confirmed impacts.
public struct GroupMetrics: Equatable, Sendable {
    /// Group centroid offset from target center, in normalized units.
    public let centerOffsetX: Double
    public let centerOffsetY: Double
    /// Mean radial distance of impacts from the group centroid.
    public let densityRadius: Double
    /// Horizontal standard deviation of the group.
    public let spreadH: Double
    /// Vertical standard deviation of the group.
    public let spreadV: Double
    public let impactCount: Int

    public var centerOffsetMagnitude: Double {
        (centerOffsetX * centerOffsetX + centerOffsetY * centerOffsetY).squareRoot()
    }
}

public enum GroupMetricsError: Error, Equatable {
    /// Fewer than two confirmed impacts: metrics would be meaningless.
    case insufficientData
}

public enum GroupMetricsCalculator {
    /// Minimum confirmed impacts required before any group metric is shown.
    public static let minimumImpacts = 2

    public static func metrics(for impacts: [ArrowImpact]) throws -> GroupMetrics {
        let points = impacts.map { ($0.xNorm, $0.yNorm) }
        return try metrics(forPoints: points)
    }

    public static func metrics(forPoints points: [(x: Double, y: Double)]) throws -> GroupMetrics {
        guard points.count >= minimumImpacts else { throw GroupMetricsError.insufficientData }
        let n = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / n
        let meanY = points.map(\.y).reduce(0, +) / n
        var density = 0.0
        var varX = 0.0
        var varY = 0.0
        for point in points {
            let dx = point.x - meanX
            let dy = point.y - meanY
            density += (dx * dx + dy * dy).squareRoot()
            varX += dx * dx
            varY += dy * dy
        }
        return GroupMetrics(
            centerOffsetX: meanX,
            centerOffsetY: meanY,
            densityRadius: density / n,
            spreadH: (varX / n).squareRoot(),
            spreadV: (varY / n).squareRoot(),
            impactCount: points.count
        )
    }
}
