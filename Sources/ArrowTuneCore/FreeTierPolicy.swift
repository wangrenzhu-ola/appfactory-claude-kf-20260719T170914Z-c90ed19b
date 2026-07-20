import Foundation

/// Free-tier limits and Pro entitlement gating.
public enum FreeTierPolicy {
    /// Free tier allows exactly one gear profile.
    public static let freeGearLimit = 1

    public static func canCreateGear(existingCount: Int, isPro: Bool) -> Bool {
        isPro || existingCount < freeGearLimit
    }

    /// Multi-gear attribution comparison is a Pro feature.
    public static func canCompareMultipleGear(selectedGearCount: Int, isPro: Bool) -> Bool {
        isPro || selectedGearCount <= freeGearLimit
    }

    /// JSON/CSV export is a Pro feature.
    public static func canExport(isPro: Bool) -> Bool {
        isPro
    }
}
