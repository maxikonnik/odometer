import SwiftUI

public struct Palette {
    public let dialFill: Color
    public let dialStroke: Color
    public let tick: Color
    public let needle: Color
    public let activeNeedle: Color
    public let zoneNormal: Color
    public let zoneWarning: Color
    public let zoneCritical: Color
    public let primaryText: Color
    public let secondaryText: Color
    public let divider: Color
    public let badgeBackground: Color
    public let panelTop: Color
    public let panelBottom: Color
    public let burnText: Color

    public static let dark = Palette(
        dialFill: Color(hex: 0x141416),
        dialStroke: Color(hex: 0x3A3A3E),
        tick: Color(hex: 0x88888E),
        needle: Color(hex: 0xE8E8EA),
        activeNeedle: Color(hex: 0xFF6B3D),
        zoneNormal: Color(hex: 0x3FB950),
        zoneWarning: Color(hex: 0xF0B429),
        zoneCritical: Color(hex: 0xF85149),
        primaryText: Color(hex: 0xE8E8EA),
        secondaryText: Color(hex: 0x808088),
        divider: Color(hex: 0x333338),
        badgeBackground: Color(hex: 0x3A3A3E),
        panelTop: Color(hex: 0x202024),
        panelBottom: Color(hex: 0x1A1A1D),
        burnText: Color(hex: 0xF0B429)
    )

    public static let light = Palette(
        dialFill: Color(hex: 0xFBFBFD),
        dialStroke: Color(hex: 0xD8D8DC),
        tick: Color(hex: 0x9A9AA0),
        needle: Color(hex: 0x1D1D1F),
        activeNeedle: Color(hex: 0xD1442A),
        zoneNormal: Color(hex: 0x2DA44E),
        zoneWarning: Color(hex: 0xD99117),
        zoneCritical: Color(hex: 0xCF222E),
        primaryText: Color(hex: 0x1D1D1F),
        secondaryText: Color(hex: 0x86868B),
        divider: Color(hex: 0xE3E3E6),
        badgeBackground: Color(hex: 0xECECF0),
        panelTop: Color(hex: 0xFFFFFF),
        panelBottom: Color(hex: 0xF5F5F7),
        burnText: Color(hex: 0xB8860B)
    )

    public static func forScheme(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }

    public func color(for zone: GaugeZone) -> Color {
        switch zone {
        case .normal: return zoneNormal
        case .warning: return zoneWarning
        case .critical: return zoneCritical
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
