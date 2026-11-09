import SwiftUI

/// The colors that travel around the glow, with an optional separate set for dark mode.
///
/// Use a preset (`.nebula`, `.ember`, `.lagoon`, `.dusk`), an array literal, or your own light and dark sets:
///
/// ```swift
/// .marqueeGlow(isActive: true, colors: .lagoon)
/// .marqueeGlow(isActive: true, colors: [.blue, .purple, .pink])
/// .marqueeGlow(isActive: true, colors: MarqueeGlowColors(light: [.blue, .teal], dark: [.cyan, .mint]))
/// ```
public struct MarqueeGlowColors: Hashable, Sendable, ExpressibleByArrayLiteral {
    public var light: [Color]
    public var dark: [Color]

    /// The same colors in light and dark mode.
    public init(_ colors: [Color]) {
        self.light = colors
        self.dark = colors
    }

    public init(light: [Color], dark: [Color]) {
        self.light = light
        self.dark = dark
    }

    public init(arrayLiteral elements: Color...) {
        self.init(elements)
    }

    /// The colors for `scheme`, ready for an `AngularGradient`: the first color is repeated at the end so the
    /// loop has no seam. An empty set falls back to `.nebula`; a single color becomes a two-tone band of that color.
    public func gradientColors(for scheme: ColorScheme) -> [Color] {
        var colors = scheme == .dark ? dark : light
        if colors.isEmpty {
            colors = scheme == .dark ? Self.nebula.dark : Self.nebula.light
        }
        if colors.count == 1 {
            colors = [colors[0], colors[0].opacity(0.35)]
        }
        return colors + [colors[0]]
    }
}

extension MarqueeGlowColors {
    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    /// Blue through violet to magenta and coral. The default.
    public static let nebula = MarqueeGlowColors(
        light: [rgb(64, 120, 255), rgb(140, 90, 250), rgb(230, 80, 200), rgb(255, 120, 120)],
        dark: [rgb(90, 150, 255), rgb(165, 120, 255), rgb(245, 110, 215), rgb(255, 150, 140)]
    )

    /// Red-orange through amber to gold.
    public static let ember = MarqueeGlowColors(
        light: [rgb(235, 80, 40), rgb(250, 130, 30), rgb(245, 180, 40), rgb(255, 210, 90)],
        dark: [rgb(255, 105, 70), rgb(255, 150, 60), rgb(255, 195, 80), rgb(255, 225, 140)]
    )

    /// Cyan, teal and green.
    public static let lagoon = MarqueeGlowColors(
        light: [rgb(0, 150, 200), rgb(0, 180, 170), rgb(60, 190, 120), rgb(120, 200, 230)],
        dark: [rgb(40, 190, 240), rgb(40, 215, 195), rgb(110, 225, 150), rgb(160, 220, 255)]
    )

    /// Indigo through rose to apricot.
    public static let dusk = MarqueeGlowColors(
        light: [rgb(90, 80, 220), rgb(190, 90, 200), rgb(240, 110, 130), rgb(250, 160, 100)],
        dark: [rgb(120, 110, 255), rgb(210, 120, 230), rgb(255, 135, 155), rgb(255, 185, 125)]
    )

    /// Every built-in preset with its name, in display order.
    public static let presets: [(name: String, colors: MarqueeGlowColors)] = [
        ("Nebula", .nebula), ("Ember", .ember), ("Lagoon", .lagoon), ("Dusk", .dusk),
    ]
}
