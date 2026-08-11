// Scripts/make-icon.swift
//
// Throwaway generator for Odometer's macOS app icon. Draws the icon
// programmatically (no image editors, no downloads) so it can be
// regenerated at any time.
//
// The design mirrors the app's own gauge:
//   - Sources/OdometerCore/UI/GaugeGeometry.swift  (angle convention)
//   - Sources/OdometerCore/UI/Palette.swift        (colours)
//   - Sources/OdometerCore/UI/GaugeView.swift       (dial/needle/hub proportions)
//
// Supports several "variants" that combine the gauge with a Claude-style
// radiating burst motif, selectable by index, so a few can be rendered
// side by side before one is picked as final.
//
// Usage:
//   swiftc -O Scripts/make-icon.swift -o /tmp/make-icon
//   /tmp/make-icon <variant 1-4> <pixelSize> <outputPNGPath>
//   /tmp/make-icon <variant 1-4> iconset <outputIconsetDir>
//
// The "iconset" mode writes every file macOS's .iconset needs
// (icon_16x16.png ... icon_512x512@2x.png), each rendered directly from
// the vector description at its target pixel size (never downscaled from
// a single bitmap). Feed the resulting directory to:
//   iconutil -c icns <iconsetDir> -o AppIcon.icns

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// MARK: - Palette (mirrors Sources/OdometerCore/UI/Palette.swift .dark, plus
// the plate gradient and the Claude-style accent colour used by the burst
// variants)

func rgba(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let plateTop: CGColor = rgba(0x2A2A30)
let plateBottom: CGColor = rgba(0x141416)
let plateStroke: CGColor = rgba(0x3A3A3E)
let dialFillColor: CGColor = rgba(0x0E0E10)
let dialStrokeColor: CGColor = rgba(0x3A3A3E)
let zoneNormalColor: CGColor = rgba(0x3FB950)
let zoneWarningColor: CGColor = rgba(0xF0B429)
let zoneCriticalColor: CGColor = rgba(0xF85149)
let tickColorC: CGColor = rgba(0x88888E)
let burstColor: CGColor = rgba(0xD97757) // Claude clay-orange, app palette, not the trademark exactly

// MARK: - Gauge geometry (mirrors Sources/OdometerCore/UI/GaugeGeometry.swift)
//
// Degrees are measured clockwise from the positive X axis in a y-down
// coordinate space, so 270 points straight up. The sweep runs from 150
// (lower left, 0%) to 390 (lower right, 100%).

let startDegrees: Double = 150
let sweepDegrees: Double = 240

func needleDegrees(percent: Double) -> Double {
    let clamped = min(max(percent, 0), 100)
    return startDegrees + (clamped / 100) * sweepDegrees
}

func zoneColor(percent: Double) -> CGColor {
    if percent >= 80 { return zoneCriticalColor }
    if percent >= 60 { return zoneWarningColor }
    return zoneNormalColor
}

// MARK: - Layout constants, in a fixed 1024x1024 design space. Every size is
// rendered by scaling this design space to the target pixel size, so small
// icons are rasterized crisply rather than downsampled from one bitmap.

let CANVAS: CGFloat = 1024
let CENTER = CGPoint(x: CANVAS / 2, y: CANVAS / 2)
let PLATE_SIZE: CGFloat = 824
let PLATE_RADIUS: CGFloat = 185
let DIAL_DIAMETER: CGFloat = 560
let DIAL_RADIUS: CGFloat = DIAL_DIAMETER / 2
let ARC_RADIUS: CGFloat = 232
let ARC_WIDTH: CGFloat = 46
let NEEDLE_PERCENT: Double = 72
let NEEDLE_ANGLE: Double = needleDegrees(percent: NEEDLE_PERCENT)

// MARK: - Shared drawing primitives

func drawPlate(_ ctx: CGContext) {
    let origin = (CANVAS - PLATE_SIZE) / 2
    let rect = CGRect(x: origin, y: origin, width: PLATE_SIZE, height: PLATE_SIZE)
    let path = CGPath(roundedRect: rect, cornerWidth: PLATE_RADIUS, cornerHeight: PLATE_RADIUS, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [plateTop, plateBottom] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.minY),
        end: CGPoint(x: rect.midX, y: rect.maxY),
        options: []
    )
    ctx.restoreGState()

    let innerRect = rect.insetBy(dx: 2, dy: 2)
    ctx.beginPath()
    ctx.addPath(CGPath(roundedRect: innerRect, cornerWidth: PLATE_RADIUS - 2, cornerHeight: PLATE_RADIUS - 2, transform: nil))
    ctx.setStrokeColor(plateStroke)
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func drawDialFace(_ ctx: CGContext) {
    let rect = CGRect(x: CENTER.x - DIAL_RADIUS, y: CENTER.y - DIAL_RADIUS, width: DIAL_DIAMETER, height: DIAL_DIAMETER)
    ctx.setFillColor(dialFillColor)
    ctx.fillEllipse(in: rect)
    ctx.beginPath()
    ctx.setStrokeColor(dialStrokeColor)
    ctx.setLineWidth(3)
    ctx.strokeEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
}

func drawZoneArc(_ ctx: CGContext, radius: CGFloat = ARC_RADIUS, width: CGFloat = ARC_WIDTH) {
    for (from, to, color) in [(0.0, 60.0, zoneNormalColor), (60.0, 80.0, zoneWarningColor), (80.0, 100.0, zoneCriticalColor)] {
        ctx.beginPath()
        ctx.addArc(
            center: CENTER,
            radius: radius,
            startAngle: CGFloat(needleDegrees(percent: from) * .pi / 180),
            endAngle: CGFloat(needleDegrees(percent: to) * .pi / 180),
            clockwise: false
        )
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }
}

func drawTicks(_ ctx: CGContext) {
    for step in 0...4 {
        let deg = needleDegrees(percent: Double(step) * 25)
        let rad = CGFloat(deg * .pi / 180)
        let innerR = ARC_RADIUS + ARC_WIDTH * 0.7
        let outerR = DIAL_RADIUS - 6
        let inner = CGPoint(x: CENTER.x + cos(rad) * innerR, y: CENTER.y + sin(rad) * innerR)
        let outer = CGPoint(x: CENTER.x + cos(rad) * outerR, y: CENTER.y + sin(rad) * outerR)
        ctx.beginPath()
        ctx.move(to: inner)
        ctx.addLine(to: outer)
        ctx.setStrokeColor(tickColorC)
        ctx.setLineWidth(6)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }
}

/// A tapered "burst" spoke, in the spirit of the Claude mark: a filled
/// wedge that is widest at the hub and comes to a point at the tip.
func drawSpoke(_ ctx: CGContext, angleDegrees: Double, innerR: CGFloat, outerR: CGFloat, baseHalfWidth: CGFloat, color: CGColor) {
    let rad = CGFloat(angleDegrees * .pi / 180)
    let dir = CGPoint(x: cos(rad), y: sin(rad))
    let perp = CGPoint(x: -sin(rad), y: cos(rad))
    let baseCenter = CGPoint(x: CENTER.x + dir.x * innerR, y: CENTER.y + dir.y * innerR)
    let left = CGPoint(x: baseCenter.x + perp.x * baseHalfWidth, y: baseCenter.y + perp.y * baseHalfWidth)
    let right = CGPoint(x: baseCenter.x - perp.x * baseHalfWidth, y: baseCenter.y - perp.y * baseHalfWidth)
    let tip = CGPoint(x: CENTER.x + dir.x * outerR, y: CENTER.y + dir.y * outerR)

    ctx.beginPath()
    ctx.move(to: left)
    ctx.addLine(to: tip)
    ctx.addLine(to: right)
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}

func drawBurst(_ ctx: CGContext, count: Int, offsetDegrees: Double = 0, innerR: CGFloat, outerR: CGFloat, baseHalfWidth: CGFloat, color: CGColor) {
    let step = 360.0 / Double(count)
    for i in 0..<count {
        drawSpoke(ctx, angleDegrees: offsetDegrees + Double(i) * step, innerR: innerR, outerR: outerR, baseHalfWidth: baseHalfWidth, color: color)
    }
}

func drawPlainHub(_ ctx: CGContext, radius: CGFloat = 30) {
    let rect = CGRect(x: CENTER.x - radius, y: CENTER.y - radius, width: radius * 2, height: radius * 2)
    ctx.setFillColor(dialFillColor)
    ctx.fillEllipse(in: rect)
    ctx.beginPath()
    ctx.setStrokeColor(burstColor)
    ctx.setLineWidth(6)
    ctx.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
}

// MARK: - Variants

/// Variant 1 - "Стрелка-луч": the classic dial (full arc + ticks), but the
/// needle itself is a single tapered burst spoke. Plain hub.
func drawVariant1(_ ctx: CGContext) {
    drawPlate(ctx)
    drawDialFace(ctx)
    drawZoneArc(ctx)
    drawTicks(ctx)
    drawSpoke(ctx, angleDegrees: NEEDLE_ANGLE, innerR: 10, outerR: DIAL_RADIUS * 0.72, baseHalfWidth: 22, color: burstColor)
    drawPlainHub(ctx, radius: 26)
}

/// Variant 2 - "Бёрст в центре": the classic dial, with a complete 8-spoke
/// Claude burst at the hub. One spoke is elongated to act as the needle.
func drawVariant2(_ ctx: CGContext) {
    drawPlate(ctx)
    drawDialFace(ctx)
    drawZoneArc(ctx)
    drawTicks(ctx)

    let count = 8
    let step = 360.0 / Double(count)
    for k in 0..<count {
        let angle = NEEDLE_ANGLE + Double(k) * step
        let isNeedle = k == 0
        let outerR: CGFloat = isNeedle ? DIAL_RADIUS * 0.72 : 90
        let baseHalfWidth: CGFloat = isNeedle ? 16 : 14
        drawSpoke(ctx, angleDegrees: angle, innerR: 8, outerR: outerR, baseHalfWidth: baseHalfWidth, color: burstColor)
    }
}

/// Variant 3 - "Дуга из лучей": no solid arc. The scale itself is built
/// from ~20 short tapered rays colored by zone, longer at the major ticks.
/// A plain needle at 72%.
func drawVariant3(_ ctx: CGContext) {
    drawPlate(ctx)
    drawDialFace(ctx)

    let rayCount = 20
    for i in 0...rayCount {
        let percent = Double(i) / Double(rayCount) * 100
        let angle = needleDegrees(percent: percent)
        let isMajor = i % 5 == 0 // 0, 25, 50, 75, 100
        let outerR: CGFloat = isMajor ? DIAL_RADIUS - 8 : DIAL_RADIUS - 44
        let innerR: CGFloat = ARC_RADIUS - 24
        let baseHalfWidth: CGFloat = isMajor ? 11 : 6
        drawSpoke(ctx, angleDegrees: angle, innerR: innerR, outerR: outerR, baseHalfWidth: baseHalfWidth, color: zoneColor(percent: percent))
    }

    drawSpoke(ctx, angleDegrees: NEEDLE_ANGLE, innerR: 10, outerR: DIAL_RADIUS * 0.72, baseHalfWidth: 14, color: burstColor)
    drawPlainHub(ctx, radius: 24)
}

/// Variant 4 - "Минимал": thick zone arc, no ticks, no needle. A centred
/// 6-spoke burst fills the middle. Meant to survive 16px as a silhouette.
func drawVariant4(_ ctx: CGContext) {
    drawPlate(ctx)
    drawDialFace(ctx)
    drawZoneArc(ctx, radius: ARC_RADIUS, width: ARC_WIDTH * 1.15)
    drawBurst(ctx, count: 6, offsetDegrees: 0, innerR: 6, outerR: 132, baseHalfWidth: 30, color: burstColor)
}

/// Variant 5 - "Бёрст-булавки": based on V2. The 8-spoke hub burst, but
/// seven of the spokes are pins - a tapered wedge whose tip is the centre
/// of a filled ball in the same colour, so the taper reads as merging into
/// the ball rather than a lollipop stuck on a stick. The eighth spoke is
/// still the plain pointed needle at 72%, deliberately un-balled so it
/// stays visually distinct as the pointer. `ballRatio` is the ball's
/// diameter as a fraction of `spokeLength` (the pin's tip radius).
struct BallSpec {
    let spokeLength: CGFloat
    let ballRatio: CGFloat
}

let ballSpecs: [String: BallSpec] = [
    "5a": BallSpec(spokeLength: 100, ballRatio: 0.30),
    "5b": BallSpec(spokeLength: 92, ballRatio: 0.42),
    "5c": BallSpec(spokeLength: 80, ballRatio: 0.55),
]

func drawVariant5(_ ctx: CGContext, spec: BallSpec) {
    drawPlate(ctx)
    drawDialFace(ctx)
    drawZoneArc(ctx)
    drawTicks(ctx)

    let count = 8
    let step = 360.0 / Double(count)
    let ballRadius = spec.spokeLength * spec.ballRatio / 2

    for k in 0..<count {
        let angle = NEEDLE_ANGLE + Double(k) * step
        if k == 0 {
            // The needle: elongated, pointed, no ball - stays the pointer.
            drawSpoke(ctx, angleDegrees: angle, innerR: 10, outerR: DIAL_RADIUS * 0.72, baseHalfWidth: 16, color: burstColor)
        } else {
            // A pin: the tapered wedge's tip is the ball's centre, so the
            // fill overlaps seamlessly instead of leaving a gap or a hard seam.
            drawSpoke(ctx, angleDegrees: angle, innerR: 8, outerR: spec.spokeLength, baseHalfWidth: 12, color: burstColor)
            let rad = CGFloat(angle * .pi / 180)
            let tip = CGPoint(x: CENTER.x + cos(rad) * spec.spokeLength, y: CENTER.y + sin(rad) * spec.spokeLength)
            let ballRect = CGRect(x: tip.x - ballRadius, y: tip.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)
            ctx.beginPath()
            ctx.setFillColor(burstColor)
            ctx.fillEllipse(in: ballRect)
        }
    }

    drawPlainHub(ctx, radius: 24)
}

/// A deterministic PRNG (splitmix64) - never `Double.random(in:)` or
/// `SystemRandomNumberGenerator`, so a given seed always renders the exact
/// same icon and the committed .icns stays reproducible from source.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextUnit() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9_007_199_254_740_992.0) // / 2^53
    }

    /// Uniform in [base * (1 - fraction), base * (1 + fraction)].
    mutating func jitter(_ base: CGFloat, fraction: CGFloat) -> CGFloat {
        let t = CGFloat(nextUnit())
        let factor = 1 + fraction * (2 * t - 1)
        return base * factor
    }
}

/// A wedge that *widens* from hub to tip (the inverse taper of `drawSpoke`):
/// narrow where it meets the hub, growing out toward the tip so it reads as
/// organic growth rather than a pin stuck onto a stick.
func drawWideningSpoke(_ ctx: CGContext, angleDegrees: Double, innerR: CGFloat, outerR: CGFloat, hubHalfWidth: CGFloat, tipHalfWidth: CGFloat, color: CGColor) {
    let rad = CGFloat(angleDegrees * .pi / 180)
    let dir = CGPoint(x: cos(rad), y: sin(rad))
    let perp = CGPoint(x: -sin(rad), y: cos(rad))
    let hubCenter = CGPoint(x: CENTER.x + dir.x * innerR, y: CENTER.y + dir.y * innerR)
    let tipCenter = CGPoint(x: CENTER.x + dir.x * outerR, y: CENTER.y + dir.y * outerR)
    let hubLeft = CGPoint(x: hubCenter.x + perp.x * hubHalfWidth, y: hubCenter.y + perp.y * hubHalfWidth)
    let hubRight = CGPoint(x: hubCenter.x - perp.x * hubHalfWidth, y: hubCenter.y - perp.y * hubHalfWidth)
    let tipLeft = CGPoint(x: tipCenter.x + perp.x * tipHalfWidth, y: tipCenter.y + perp.y * tipHalfWidth)
    let tipRight = CGPoint(x: tipCenter.x - perp.x * tipHalfWidth, y: tipCenter.y - perp.y * tipHalfWidth)

    ctx.beginPath()
    ctx.move(to: hubLeft)
    ctx.addLine(to: tipLeft)
    ctx.addLine(to: tipRight)
    ctx.addLine(to: hubRight)
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}

/// Variant 6 - "Органика": based on V5b (medium balls). Spokes invert the
/// V5 taper - narrow at the hub, widening toward the tip - so they read as
/// wedges growing out of the centre. Each of the 7 non-needle balls jitters
/// independently in size (+/-20% of the V5b base diameter) and in distance
/// from the hub (+/-30% of the V5b base radius); the spoke is redrawn to
/// whatever length its own jittered ball landed at, so it always meets the
/// ball with no gap and no overshoot. The needle spoke is exempt from all
/// of it: fixed length, fixed width, pointed, no ball, no jitter - the one
/// deliberately regular element in an otherwise hand-thrown burst.
func drawVariant6(_ ctx: CGContext, seed: UInt64) {
    drawPlate(ctx)
    drawDialFace(ctx)
    drawZoneArc(ctx)
    drawTicks(ctx)

    var rng = SeededRNG(seed: seed)
    let base = ballSpecs["5b"]! // medium base: spokeLength 92, ballRatio 0.42
    let baseRadius = base.spokeLength
    let baseBallDiameter = base.spokeLength * base.ballRatio

    let count = 8
    let step = 360.0 / Double(count)
    for k in 0..<count {
        let angle = NEEDLE_ANGLE + Double(k) * step
        if k == 0 {
            // The needle: fixed, pointed, no ball, no jitter.
            drawSpoke(ctx, angleDegrees: angle, innerR: 10, outerR: DIAL_RADIUS * 0.72, baseHalfWidth: 16, color: burstColor)
            continue
        }
        let radius = rng.jitter(baseRadius, fraction: 0.30)
        let ballDiameter = rng.jitter(baseBallDiameter, fraction: 0.20)
        let ballRadius = ballDiameter / 2
        // The tip is exactly as wide as the ball it grows into, and the hub
        // end is 35-40% of that - "roughly 35-40% of the tip width at the
        // hub end."
        let tipHalfWidth = ballRadius
        let hubHalfWidth = tipHalfWidth * 0.375
        drawWideningSpoke(ctx, angleDegrees: angle, innerR: 8, outerR: radius, hubHalfWidth: hubHalfWidth, tipHalfWidth: tipHalfWidth, color: burstColor)

        let rad = CGFloat(angle * .pi / 180)
        let tip = CGPoint(x: CENTER.x + cos(rad) * radius, y: CENTER.y + sin(rad) * radius)
        let ballRect = CGRect(x: tip.x - ballRadius, y: tip.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)
        ctx.beginPath()
        ctx.setFillColor(burstColor)
        ctx.fillEllipse(in: ballRect)
    }

    drawPlainHub(ctx, radius: 24)
}

func drawVariant(_ key: String, _ ctx: CGContext, seed: UInt64 = 0) {
    if let spec = ballSpecs[key] {
        drawVariant5(ctx, spec: spec)
        return
    }
    switch key {
    case "1": drawVariant1(ctx)
    case "2": drawVariant2(ctx)
    case "3": drawVariant3(ctx)
    case "4": drawVariant4(ctx)
    case "6": drawVariant6(ctx, seed: seed)
    default: fatalError("unknown variant \(key)")
    }
}

// MARK: - Rendering

func renderImage(variant: String, pixelSize: Int, seed: UInt64 = 0) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create bitmap context")
    }
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Flip to a y-down space matching GaugeGeometry's convention, then scale
    // the whole 1024-unit design space down to the requested pixel size.
    ctx.translateBy(x: 0, y: CGFloat(pixelSize))
    ctx.scaleBy(x: 1, y: -1)
    let scale = CGFloat(pixelSize) / CANVAS
    ctx.scaleBy(x: scale, y: scale)

    drawVariant(variant, ctx, seed: seed)

    guard let image = ctx.makeImage() else { fatalError("Could not rasterize image") }
    return image
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image destination for \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Could not finalize PNG at \(path)")
    }
}

// MARK: - Entry point

let validVariants: Set<String> = ["1", "2", "3", "4", "5a", "5b", "5c", "6"]

let args = CommandLine.arguments
func usage() -> Never {
    print("""
    Usage:
      make-icon <variant 1-4|5a|5b|5c> <pixelSize> <outputPNGPath>
      make-icon <variant 1-4|5a|5b|5c> iconset <outputIconsetDir>
      make-icon 6 <pixelSize> <outputPNGPath> <seed>
      make-icon 6 iconset <outputIconsetDir> <seed>
    """)
    exit(1)
}

guard args.count >= 4, validVariants.contains(args[1]) else { usage() }
let variant = args[1]

var seed: UInt64 = 0
if variant == "6" {
    guard args.count >= 5, let parsedSeed = UInt64(args[4]) else {
        print("error: variant 6 requires an integer seed as the last argument")
        exit(1)
    }
    seed = parsedSeed
    print("Using seed \(seed)")
}

if args[2] == "iconset" {
    let outDir = args[3]
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let entries: [(String, Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]
    for (name, size) in entries {
        let img = renderImage(variant: variant, pixelSize: size, seed: seed)
        savePNG(img, to: "\(outDir)/\(name).png")
        print("Wrote \(outDir)/\(name).png (\(size)x\(size))")
    }
} else if let pixelSize = Int(args[2]) {
    let img = renderImage(variant: variant, pixelSize: pixelSize, seed: seed)
    savePNG(img, to: args[3])
    print("Wrote \(args[3]) (variant \(variant), \(pixelSize)px)")
} else {
    usage()
}
