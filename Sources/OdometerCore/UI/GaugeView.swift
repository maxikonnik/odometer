import SwiftUI

public struct GaugeView: View {
    public let percent: Double?
    public let caption: String
    public let subcaption: String?
    public let diameter: CGFloat
    public let isPrimary: Bool

    @Environment(\.colorScheme) private var scheme

    public init(
        percent: Double?,
        caption: String,
        subcaption: String? = nil,
        diameter: CGFloat = 76,
        isPrimary: Bool = false
    ) {
        self.percent = percent
        self.caption = caption
        self.subcaption = subcaption
        self.diameter = diameter
        self.isPrimary = isPrimary
    }

    public var body: some View {
        let palette = Palette.forScheme(scheme)
        VStack(spacing: 2) {
            Canvas { context, size in draw(in: &context, size: size, palette: palette) }
                .frame(width: diameter, height: diameter)
                .accessibilityLabel(caption)
                .accessibilityValue(percent.map { "\(Int($0.rounded()))%" } ?? "нет данных")

            VStack(spacing: 0) {
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                if let subcaption {
                    Text(subcaption)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, palette: Palette) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        let arcRadius = radius * 0.86
        let lineWidth = radius * 0.11

        context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(palette.dialFill))
        context.stroke(
            Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)),
            with: .color(palette.dialStroke),
            lineWidth: 1.5
        )

        // Zone arcs: green to 60%, amber to 80%, red to 100%.
        for (from, to, zone) in [(0.0, 60.0, GaugeZone.normal),
                                 (60.0, 80.0, .warning),
                                 (80.0, 100.0, .critical)] {
            var path = Path()
            path.addArc(
                center: center,
                radius: arcRadius,
                startAngle: .degrees(GaugeGeometry.needleDegrees(percent: from)),
                endAngle: .degrees(GaugeGeometry.needleDegrees(percent: to)),
                clockwise: false
            )
            context.stroke(
                path,
                with: .color(palette.color(for: zone)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }

        // Five major ticks across the sweep.
        for step in 0...4 {
            let degrees = GaugeGeometry.needleDegrees(percent: Double(step) * 25)
            let radians = CGFloat(degrees) * .pi / 180
            let inner = CGPoint(
                x: center.x + cos(radians) * (arcRadius + lineWidth * 0.7),
                y: center.y + sin(radians) * (arcRadius + lineWidth * 0.7)
            )
            let outer = CGPoint(
                x: center.x + cos(radians) * (radius - 1),
                y: center.y + sin(radians) * (radius - 1)
            )
            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            context.stroke(tick, with: .color(palette.tick), lineWidth: 1.5)
        }

        guard let percent else {
            context.draw(
                Text("—")
                    .font(.system(size: radius * 0.42, weight: .bold))
                    .foregroundStyle(palette.secondaryText),
                at: CGPoint(x: center.x, y: center.y + radius * 0.42)
            )
            return
        }

        let needleColor = isPrimary ? palette.activeNeedle : palette.needle
        let radians = CGFloat(GaugeGeometry.needleDegrees(percent: percent)) * .pi / 180
        var needle = Path()
        needle.move(to: center)
        needle.addLine(to: CGPoint(
            x: center.x + cos(radians) * arcRadius * 0.72,
            y: center.y + sin(radians) * arcRadius * 0.72
        ))
        context.stroke(
            needle,
            with: .color(needleColor),
            style: StrokeStyle(lineWidth: radius * 0.055, lineCap: .round)
        )

        let hubRadius = radius * 0.1
        let hub = CGRect(
            x: center.x - hubRadius, y: center.y - hubRadius,
            width: hubRadius * 2, height: hubRadius * 2
        )
        context.fill(Path(ellipseIn: hub), with: .color(palette.dialFill))
        context.stroke(Path(ellipseIn: hub), with: .color(needleColor), lineWidth: 1.5)

        context.draw(
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: radius * 0.4, weight: .bold))
                .foregroundStyle(palette.primaryText),
            at: CGPoint(x: center.x, y: center.y + radius * 0.44)
        )
    }
}
