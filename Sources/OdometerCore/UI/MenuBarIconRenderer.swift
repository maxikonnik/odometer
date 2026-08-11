import AppKit
import SwiftUI

public enum MenuBarIconRenderer {
    /// Renders the dial glyph plus percentage into a menu-bar-sized image.
    /// The normal state is a template image so macOS tints it for the current
    /// menu bar appearance; coloured states opt out so the tint survives.
    @MainActor
    public static func image(percent: Double?, zone: GaugeZone, isAttention: Bool) -> NSImage {
        let tint: Color? = isAttention
            ? Color(hex: 0xFF6B3D)
            : (zone == .critical ? Color(hex: 0xF85149) : nil)

        let view = MenuBarIconView(percent: percent, tint: tint ?? .primary)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = (tint == nil)
        return image
    }
}

private struct MenuBarIconView: View {
    let percent: Double?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 1

                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(GaugeGeometry.needleDegrees(percent: 0)),
                    endAngle: .degrees(GaugeGeometry.needleDegrees(percent: 100)),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(tint),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )

                let radians = CGFloat(GaugeGeometry.needleDegrees(percent: percent ?? 0)) * .pi / 180
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: CGPoint(
                    x: center.x + cos(radians) * radius * 0.78,
                    y: center.y + sin(radians) * radius * 0.78
                ))
                context.stroke(
                    needle,
                    with: .color(tint),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)),
                    with: .color(tint)
                )
            }
            .frame(width: 15, height: 15)

            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 1)
    }
}
