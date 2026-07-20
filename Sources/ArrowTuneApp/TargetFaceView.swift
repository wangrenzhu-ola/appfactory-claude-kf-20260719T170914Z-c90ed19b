import SwiftUI

/// Vector-drawn WA target face with impact markers, group-center crosshair,
/// and density ellipse. This is the vis-target-face-hero and
/// vis-group-density-overlay slot: fully vector, no external imagery.
struct TargetFaceView: View {
    let face: TargetFace
    var impacts: [ArrowImpact] = []
    var draftImpacts: [ArrowImpact] = []
    var metrics: GroupMetrics? = nil
    var showsOverlay: Bool = true
    var onTap: ((Double, Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 2.0
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Rings, outer 1 to inner 10.
                for ring in 1...10 {
                    let radius = scale * Double(11 - ring) / 10.0
                    let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2)
                    let path = Path(ellipseIn: rect)
                    context.fill(path, with: .color(Theme.ringFill(ring: ring)))
                    context.stroke(path, with: .color(Theme.ink.opacity(0.35)), lineWidth: 0.6)
                    if ring <= 10 {
                        let labelPoint = CGPoint(x: center.x, y: center.y - radius + scale * 0.05)
                        let text = Text("\(11 - ring)")
                            .font(.system(size: max(7, scale * 0.055), design: .monospaced))
                            .foregroundColor(Theme.ringText(ring: ring))
                        context.draw(text, at: labelPoint)
                    }
                }
                // Fine crosshair at true center.
                var cross = Path()
                cross.move(to: CGPoint(x: center.x - scale * 0.035, y: center.y))
                cross.addLine(to: CGPoint(x: center.x + scale * 0.035, y: center.y))
                cross.move(to: CGPoint(x: center.x, y: center.y - scale * 0.035))
                cross.addLine(to: CGPoint(x: center.x, y: center.y + scale * 0.035))
                context.stroke(cross, with: .color(Theme.ink.opacity(0.5)), lineWidth: 0.8)

                if showsOverlay, let metrics {
                    // Density ellipse: spreadH × spreadV at the group centroid.
                    let ex = center.x + metrics.centerOffsetX * scale
                    let ey = center.y - metrics.centerOffsetY * scale
                    let ew = max(metrics.spreadH * scale * 2, 6)
                    let eh = max(metrics.spreadV * scale * 2, 6)
                    let ellipse = Path(ellipseIn: CGRect(x: ex - ew / 2, y: ey - eh / 2, width: ew, height: eh))
                    context.stroke(ellipse, with: .color(Theme.signal), style: .init(lineWidth: 1.4, dash: [5, 3]))
                    var centerMark = Path()
                    centerMark.move(to: CGPoint(x: ex - 9, y: ey))
                    centerMark.addLine(to: CGPoint(x: ex + 9, y: ey))
                    centerMark.move(to: CGPoint(x: ex, y: ey - 9))
                    centerMark.addLine(to: CGPoint(x: ex, y: ey + 9))
                    context.stroke(centerMark, with: .color(Theme.signal), lineWidth: 1.6)
                }

                // Confirmed impacts: solid signal-orange dots with ring label.
                for impact in impacts {
                    let p = CGPoint(x: center.x + impact.xNorm * scale,
                                    y: center.y - impact.yNorm * scale)
                    let dot = Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
                    context.fill(dot, with: .color(Theme.signal))
                    context.stroke(dot, with: .color(.white), lineWidth: 1)
                }
                // Draft proposals: hollow editable markers.
                for impact in draftImpacts {
                    let p = CGPoint(x: center.x + impact.xNorm * scale,
                                    y: center.y - impact.yNorm * scale)
                    let dot = Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
                    context.stroke(dot, with: .color(Theme.signal), lineWidth: 1.8)
                    let text = Text("\(impact.ringValue)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.signal)
                    context.draw(text, at: CGPoint(x: p.x + 11, y: p.y - 9))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard let onTap else { return }
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let x = (value.location.x - center.x) / scale
                        let y = (center.y - value.location.y) / scale
                        onTap(x, y)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.paper)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
    }

    private var accessibilitySummary: String {
        var parts = ["Target face, \(face.displayName)"]
        if !impacts.isEmpty { parts.append("\(impacts.count) arrows plotted") }
        if !draftImpacts.isEmpty { parts.append("\(draftImpacts.count) proposals awaiting confirmation") }
        if let metrics {
            parts.append(String(format: "group center offset %.1f centimeters", metrics.centerOffsetMagnitude * face.scoringRadiusCm))
        }
        return parts.joined(separator: ", ")
    }
}
