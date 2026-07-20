import Foundation

/// On-device, deterministic group-shape diagnosis. Diagnosis describes the
/// measured group shape and lists plausible contributing factors; it never
/// claims causation between a tuning change and a metric shift.
public struct Diagnosis: Equatable, Sendable {
    public let patternLabel: String
    public let possibleCauses: [String]
    public let confidence: Double
}

public enum DiagnosisEngine {
    /// Thresholds are expressed in normalized scoring-radius units.
    private static let offsetThreshold = 0.15
    private static let stringingRatio = 1.8
    private static let tightDensity = 0.18
    private static let looseDensity = 0.45

    public static func diagnose(metrics: GroupMetrics) -> Diagnosis {
        var labels: [String] = []
        var causes: [String] = []

        if metrics.centerOffsetX < -offsetThreshold {
            labels.append("left drift")
            causes.append("Sight or plunger position may be biased left; check arrow rest alignment.")
        } else if metrics.centerOffsetX > offsetThreshold {
            labels.append("right drift")
            causes.append("Sight or plunger position may be biased right; check arrow rest alignment.")
        }
        if metrics.centerOffsetY > offsetThreshold {
            labels.append("high placement")
            causes.append("Nocking point or sight elevation may be set high for this distance.")
        } else if metrics.centerOffsetY < -offsetThreshold {
            labels.append("low placement")
            causes.append("Nocking point or sight elevation may be set low for this distance.")
        }

        let maxSpread = max(metrics.spreadH, metrics.spreadV)
        let minSpread = max(min(metrics.spreadH, metrics.spreadV), 0.0001)
        if maxSpread / minSpread >= stringingRatio {
            if metrics.spreadV > metrics.spreadH {
                labels.append("vertical stringing")
                causes.append("Vertical dispersion often tracks nocking-point or spine inconsistencies.")
            } else {
                labels.append("horizontal stringing")
                causes.append("Horizontal dispersion often tracks plunger tension or release inconsistencies.")
            }
        }

        if metrics.densityRadius <= tightDensity {
            labels.append("tight group")
        } else if metrics.densityRadius >= looseDensity {
            labels.append("loose group")
            causes.append("Wide density radius suggests inconsistent form or mismatched arrow setup.")
        }

        if labels.isEmpty {
            labels.append("centered group")
        }
        if causes.isEmpty {
            causes.append("Group shape is within typical bounds; keep current setup and keep logging.")
        }

        // Confidence grows with impact count and penalizes very loose groups.
        let countFactor = min(1.0, Double(metrics.impactCount) / 12.0)
        let densityPenalty = min(1.0, metrics.densityRadius / looseDensity)
        let confidence = max(0.2, min(0.95, 0.4 + 0.55 * countFactor - 0.2 * densityPenalty))

        return Diagnosis(
            patternLabel: labels.joined(separator: ", "),
            possibleCauses: causes,
            confidence: confidence
        )
    }

    /// Builds a persisted report for a session from its confirmed impacts.
    public static func report(sessionID: UUID, impacts: [ArrowImpact]) throws -> DiagnosisReport {
        let metrics = try GroupMetricsCalculator.metrics(for: impacts)
        let diagnosis = diagnose(metrics: metrics)
        return DiagnosisReport(
            sessionID: sessionID,
            centerOffsetX: metrics.centerOffsetX,
            centerOffsetY: metrics.centerOffsetY,
            densityRadius: metrics.densityRadius,
            spreadH: metrics.spreadH,
            spreadV: metrics.spreadV,
            patternLabel: diagnosis.patternLabel,
            confidence: diagnosis.confidence
        )
    }
}
