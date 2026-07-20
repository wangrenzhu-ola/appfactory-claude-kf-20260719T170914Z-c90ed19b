import SwiftUI

/// Precision-instrument design language for ArrowTune.
/// The target face is treated as a measuring instrument: paper-white ground,
/// deep ink for structure, one signal color for measured values.
enum Theme {
    /// Target-paper white.
    static let paper = Color(red: 0.985, green: 0.981, blue: 0.965)
    /// Deep blue-black ink (#10233A) — structure, text, ring lines.
    static let ink = Color(red: 0.063, green: 0.137, blue: 0.227)
    /// Signal orange (#E86A2C) — measured values: impacts, group center, event markers.
    static let signal = Color(red: 0.910, green: 0.416, blue: 0.173)
    /// Neutral grays.
    static let inkSoft = Color(red: 0.063, green: 0.137, blue: 0.227).opacity(0.62)
    static let hairline = Color(red: 0.063, green: 0.137, blue: 0.227).opacity(0.18)
    static let cardGround = Color.white
    /// Functional tones kept deliberately quiet.
    static let ok = Color(red: 0.16, green: 0.48, blue: 0.32)
    static let warn = Color(red: 0.72, green: 0.22, blue: 0.18)

    /// Ring colors of a WA target face, outer (1) to inner (10).
    static func ringFill(ring: Int) -> Color {
        switch ring {
        case 1, 2: return Color(red: 0.93, green: 0.92, blue: 0.90) // paper white
        case 3, 4: return Color(red: 0.62, green: 0.64, blue: 0.66) // gray zone
        case 5, 6: return Color(red: 0.16, green: 0.42, blue: 0.62) // blue zone
        case 7, 8: return Color(red: 0.78, green: 0.24, blue: 0.22) // red zone
        default:   return Color(red: 0.90, green: 0.68, blue: 0.20) // gold
        }
    }

    static func ringText(ring: Int) -> Color {
        switch ring {
        case 1, 2, 9, 10: return .black.opacity(0.75)
        default: return .white.opacity(0.9)
        }
    }
}

/// Numeric readout style: monospaced digits for instrument readings.
struct ReadoutStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .monospaced).monospacedDigit())
            .foregroundColor(Theme.ink)
    }
}

extension View {
    func readout() -> some View { modifier(ReadoutStyle()) }
}

/// Thin labeled metric cell used on group and diagnosis screens.
struct MetricCell: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.inkSoft)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).readout().font(.system(.title3, design: .monospaced).monospacedDigit())
                Text(unit).font(.caption2).foregroundColor(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.cardGround)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

/// Inline status bar for save success / failure and detection fallback.
struct StatusBar: View {
    enum Kind { case success, failure, info }
    let kind: Kind
    let text: String

    private var tint: Color {
        switch kind {
        case .success: return Theme.ok
        case .failure: return Theme.warn
        case .info: return Theme.ink
        }
    }
    private var icon: String {
        switch kind {
        case .success: return "checkmark.circle"
        case .failure: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(tint)
            Text(text).font(.footnote).foregroundColor(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(tint.opacity(0.08))
        .overlay(Rectangle().stroke(tint.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Quiet section header with an instrument-label feel.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .monospaced))
            .kerning(1.2)
            .foregroundColor(Theme.inkSoft)
    }
}
