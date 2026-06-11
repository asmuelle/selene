#if canImport(SwiftUI)
    import SwiftUI
#endif

/// Lunar Almanac design tokens (DESIGN.md visual direction).
///
/// Raw sRGB components live here as plain values so token discipline is testable
/// without SwiftUI; `Color` accessors are derived. Both themes are first-class:
/// night ("observatory") and daylight ("almanac paper").
public struct ColorToken: Hashable, Sendable {
    public let name: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(_ name: String, _ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1) {
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    #if canImport(SwiftUI)
        public var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
        }
    #endif
}

/// The complete palette. sRGB approximations of the committed oklch values.
public enum SelenePalette {
    /// Deep ink indigo — night surface. oklch(22% 0.04 280).
    public static let inkIndigo = ColorToken("inkIndigo", 0.106, 0.098, 0.157)
    /// Slightly lifted indigo for cards/layers on the night surface.
    public static let inkIndigoRaised = ColorToken("inkIndigoRaised", 0.145, 0.137, 0.212)
    /// Warm moonlight ivory — night text, daylight surface. oklch(96% 0.015 90).
    public static let moonlightIvory = ColorToken("moonlightIvory", 0.957, 0.937, 0.890)
    /// Daylight paper, a touch warmer than ivory text.
    public static let almanacPaper = ColorToken("almanacPaper", 0.973, 0.957, 0.914)
    /// Single lunar-gold accent — reserved for *today* and confirmed events.
    public static let lunarGold = ColorToken("lunarGold", 0.871, 0.722, 0.392)
    /// Semantic dusty rose — flow data only.
    public static let dustyRose = ColorToken("dustyRose", 0.780, 0.545, 0.576)
    /// Semantic sage — fertile-window bands only.
    public static let sage = ColorToken("sage", 0.604, 0.706, 0.592)
    /// Muted indigo-grey for secondary text on night surfaces.
    public static let stardust = ColorToken("stardust", 0.616, 0.604, 0.690)

    public static let all: [ColorToken] = [
        inkIndigo, inkIndigoRaised, moonlightIvory, almanacPaper,
        lunarGold, dustyRose, sage, stardust,
    ]
}

/// Semantic theme mapping. Light is "daylight almanac", not an afterthought.
public struct SeleneTheme: Hashable, Sendable {
    public let surface: ColorToken
    public let surfaceRaised: ColorToken
    public let text: ColorToken
    public let textSecondary: ColorToken
    public let accentToday: ColorToken
    public let flow: ColorToken
    public let fertileBand: ColorToken

    public static let night = SeleneTheme(
        surface: SelenePalette.inkIndigo,
        surfaceRaised: SelenePalette.inkIndigoRaised,
        text: SelenePalette.moonlightIvory,
        textSecondary: SelenePalette.stardust,
        accentToday: SelenePalette.lunarGold,
        flow: SelenePalette.dustyRose,
        fertileBand: SelenePalette.sage
    )

    public static let daylight = SeleneTheme(
        surface: SelenePalette.almanacPaper,
        surfaceRaised: SelenePalette.moonlightIvory,
        text: SelenePalette.inkIndigo,
        textSecondary: ColorToken("inkMuted", 0.337, 0.325, 0.420),
        accentToday: SelenePalette.lunarGold,
        flow: SelenePalette.dustyRose,
        fertileBand: SelenePalette.sage
    )
}

/// Spacing rhythm (pt). Intentional scale, not uniform padding.
public enum SeleneSpacing {
    public static let hairline = 2.0
    public static let tight = 6.0
    public static let element = 12.0
    public static let block = 20.0
    public static let section = 34.0
}
