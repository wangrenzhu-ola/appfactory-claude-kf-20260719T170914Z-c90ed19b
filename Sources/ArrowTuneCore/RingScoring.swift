import Foundation

/// Converts normalized target coordinates into ring values and physical distances.
///
/// Coordinates are expressed in units of the target's scoring radius: (0, 0) is
/// target center and radius 1.0 is the outer edge of the 1-ring.
public enum RingScoring {
    /// Ring value for a normalized radial distance. Returns 0 for a miss
    /// (beyond the outer scoring ring). Inner ten counts as 10.
    public static func ringValue(xNorm: Double, yNorm: Double) -> Int {
        let r = (xNorm * xNorm + yNorm * yNorm).squareRoot()
        return ringValue(radiusNorm: r)
    }

    public static func ringValue(radiusNorm: Double) -> Int {
        guard radiusNorm.isFinite, radiusNorm >= 0 else { return 0 }
        if radiusNorm > 1.0 { return 0 }
        // Rings are 0.1 wide in normalized units; 0.0...0.1 scores 10.
        let ring = 10 - Int(floor(radiusNorm * 10.0))
        return max(1, min(10, ring))
    }

    /// Physical distance from target center in centimeters for a given face.
    public static func distanceCm(xNorm: Double, yNorm: Double, face: TargetFace) -> Double {
        let r = (xNorm * xNorm + yNorm * yNorm).squareRoot()
        return r * face.scoringRadiusCm
    }

    /// Converts a physical radial distance (cm) back to normalized units.
    public static func normalizedRadius(distanceCm: Double, face: TargetFace) -> Double {
        distanceCm / face.scoringRadiusCm
    }
}
