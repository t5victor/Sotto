import AppKit
import SwiftUI

public struct SottoSRGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    fileprivate var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

public struct SottoColorPair: Equatable, Sendable {
    public let background: SottoSRGB
    public let foreground: SottoSRGB

    public init(background: SottoSRGB, foreground: SottoSRGB) {
        self.background = background
        self.foreground = foreground
    }
}

public struct SottoAdaptiveColorPair: Equatable, Sendable {
    public let light: SottoColorPair
    public let dark: SottoColorPair

    public init(light: SottoColorPair, dark: SottoColorPair) {
        self.light = light
        self.dark = dark
    }
}

public enum SottoPalette {
    public static let violetAccent = SottoColorPair(
        background: SottoSRGB(red: 0.45, green: 0.34, blue: 0.95),
        foreground: SottoSRGB(red: 1, green: 1, blue: 1)
    )
    public static let blueAccent = SottoColorPair(
        background: SottoSRGB(red: 30.0 / 255, green: 101.0 / 255, blue: 200.0 / 255),
        foreground: SottoSRGB(red: 1, green: 1, blue: 1)
    )
    public static let coralAccent = SottoColorPair(
        background: SottoSRGB(red: 201.0 / 255, green: 67.0 / 255, blue: 55.0 / 255),
        foreground: SottoSRGB(red: 1, green: 1, blue: 1)
    )
    public static let greenAccent = SottoColorPair(
        background: SottoSRGB(red: 22.0 / 255, green: 125.0 / 255, blue: 75.0 / 255),
        foreground: SottoSRGB(red: 1, green: 1, blue: 1)
    )
    public static let destructiveAction = SottoColorPair(
        background: SottoSRGB(red: 196.0 / 255, green: 46.0 / 255, blue: 55.0 / 255),
        foreground: SottoSRGB(red: 1, green: 1, blue: 1)
    )
    public static let successStatus = SottoAdaptiveColorPair(
        light: SottoColorPair(
            background: SottoSRGB(red: 232.0 / 255, green: 246.0 / 255, blue: 238.0 / 255),
            foreground: SottoSRGB(red: 17.0 / 255, green: 96.0 / 255, blue: 51.0 / 255)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(red: 23.0 / 255, green: 52.0 / 255, blue: 36.0 / 255),
            foreground: SottoSRGB(red: 169.0 / 255, green: 239.0 / 255, blue: 199.0 / 255)
        )
    )
    public static let warningStatus = SottoAdaptiveColorPair(
        light: SottoColorPair(
            background: SottoSRGB(red: 255.0 / 255, green: 243.0 / 255, blue: 214.0 / 255),
            foreground: SottoSRGB(red: 107.0 / 255, green: 71.0 / 255, blue: 0)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(red: 60.0 / 255, green: 46.0 / 255, blue: 18.0 / 255),
            foreground: SottoSRGB(red: 255.0 / 255, green: 216.0 / 255, blue: 135.0 / 255)
        )
    )
    public static let destructiveStatus = SottoAdaptiveColorPair(
        light: SottoColorPair(
            background: SottoSRGB(red: 252.0 / 255, green: 235.0 / 255, blue: 236.0 / 255),
            foreground: SottoSRGB(red: 143.0 / 255, green: 29.0 / 255, blue: 40.0 / 255)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(red: 64.0 / 255, green: 29.0 / 255, blue: 33.0 / 255),
            foreground: SottoSRGB(red: 255.0 / 255, green: 185.0 / 255, blue: 191.0 / 255)
        )
    )

    public static let accentPairs = [
        violetAccent,
        blueAccent,
        coralAccent,
        greenAccent,
    ]
    public static let statusPairs = [
        successStatus,
        warningStatus,
        destructiveStatus,
    ]
}

/// The complete set of visual decisions used by Sotto components.
///
/// Like shadcn/ui, the values and components live in the application repository.
/// Create another theme, or replace individual values, without changing component code.
public struct SottoTheme: Sendable {
    public struct Colors: Sendable {
        public var canvas: Color
        public var surface: Color
        public var raisedSurface: Color
        public var mutedSurface: Color
        public var border: Color
        public var foreground: Color
        public var mutedForeground: Color
        public var subtleForeground: Color
        public var accent: Color
        public var accentForeground: Color
        public var success: Color
        public var successForeground: Color
        public var successBackground: Color
        public var warning: Color
        public var warningForeground: Color
        public var warningBackground: Color
        public var destructive: Color
        public var destructiveButtonForeground: Color
        public var destructiveForeground: Color
        public var destructiveBackground: Color

        public init(
            canvas: Color,
            surface: Color,
            raisedSurface: Color,
            mutedSurface: Color,
            border: Color,
            foreground: Color,
            mutedForeground: Color,
            subtleForeground: Color,
            accent: Color,
            accentForeground: Color,
            success: Color,
            successForeground: Color,
            successBackground: Color,
            warning: Color,
            warningForeground: Color,
            warningBackground: Color,
            destructive: Color,
            destructiveButtonForeground: Color,
            destructiveForeground: Color,
            destructiveBackground: Color
        ) {
            self.canvas = canvas
            self.surface = surface
            self.raisedSurface = raisedSurface
            self.mutedSurface = mutedSurface
            self.border = border
            self.foreground = foreground
            self.mutedForeground = mutedForeground
            self.subtleForeground = subtleForeground
            self.accent = accent
            self.accentForeground = accentForeground
            self.success = success
            self.successForeground = successForeground
            self.successBackground = successBackground
            self.warning = warning
            self.warningForeground = warningForeground
            self.warningBackground = warningBackground
            self.destructive = destructive
            self.destructiveButtonForeground = destructiveButtonForeground
            self.destructiveForeground = destructiveForeground
            self.destructiveBackground = destructiveBackground
        }
    }

    public struct Spacing: Equatable, Sendable {
        public var xxs: CGFloat
        public var xs: CGFloat
        public var sm: CGFloat
        public var md: CGFloat
        public var lg: CGFloat
        public var xl: CGFloat
        public var xxl: CGFloat

        public init(
            xxs: CGFloat = 2,
            xs: CGFloat = 4,
            sm: CGFloat = 8,
            md: CGFloat = 12,
            lg: CGFloat = 16,
            xl: CGFloat = 24,
            xxl: CGFloat = 32
        ) {
            self.xxs = xxs
            self.xs = xs
            self.sm = sm
            self.md = md
            self.lg = lg
            self.xl = xl
            self.xxl = xxl
        }
    }

    public struct Radii: Equatable, Sendable {
        public var small: CGFloat
        public var medium: CGFloat
        public var large: CGFloat
        public var pill: CGFloat

        public init(
            small: CGFloat = 6,
            medium: CGFloat = 10,
            large: CGFloat = 14,
            pill: CGFloat = 999
        ) {
            self.small = small
            self.medium = medium
            self.large = large
            self.pill = pill
        }
    }

    public struct ControlHeights: Equatable, Sendable {
        public var small: CGFloat
        public var regular: CGFloat
        public var large: CGFloat

        public init(small: CGFloat = 28, regular: CGFloat = 34, large: CGFloat = 42) {
            self.small = small
            self.regular = regular
            self.large = large
        }
    }

    public struct Typography: Sendable {
        public var pageTitle: Font
        public var sectionTitle: Font
        public var body: Font
        public var label: Font
        public var caption: Font

        public init(
            pageTitle: Font = .system(size: 26, weight: .semibold, design: .rounded),
            sectionTitle: Font = .system(size: 15, weight: .semibold),
            body: Font = .system(size: 13),
            label: Font = .system(size: 13, weight: .medium),
            caption: Font = .system(size: 11, weight: .medium)
        ) {
            self.pageTitle = pageTitle
            self.sectionTitle = sectionTitle
            self.body = body
            self.label = label
            self.caption = caption
        }
    }

    public struct Motion: Equatable, Sendable {
        public var fast: Double
        public var regular: Double
        public var slow: Double

        public init(fast: Double = 0.12, regular: Double = 0.2, slow: Double = 0.32) {
            self.fast = fast
            self.regular = regular
            self.slow = slow
        }
    }

    public var colors: Colors
    public var spacing: Spacing
    public var radii: Radii
    public var controlHeights: ControlHeights
    public var typography: Typography
    public var motion: Motion

    public init(
        colors: Colors,
        spacing: Spacing = .init(),
        radii: Radii = .init(),
        controlHeights: ControlHeights = .init(),
        typography: Typography = .init(),
        motion: Motion = .init()
    ) {
        self.colors = colors
        self.spacing = spacing
        self.radii = radii
        self.controlHeights = controlHeights
        self.typography = typography
        self.motion = motion
    }

    public static var standard: SottoTheme {
        SottoTheme(
            colors: Colors(
                canvas: Color(nsColor: .windowBackgroundColor),
                surface: Color(nsColor: .controlBackgroundColor),
                raisedSurface: Color(nsColor: .textBackgroundColor),
                mutedSurface: Color(nsColor: .underPageBackgroundColor),
                border: Color(nsColor: .separatorColor),
                foreground: Color(nsColor: .labelColor),
                mutedForeground: Color(nsColor: .secondaryLabelColor),
                subtleForeground: Color(nsColor: .tertiaryLabelColor),
                accent: SottoPalette.violetAccent.background.color,
                accentForeground: SottoPalette.violetAccent.foreground.color,
                success: Color(red: 0.18, green: 0.64, blue: 0.39),
                successForeground: dynamicColor(
                    light: SottoPalette.successStatus.light.foreground.nsColor,
                    dark: SottoPalette.successStatus.dark.foreground.nsColor
                ),
                successBackground: dynamicColor(
                    light: SottoPalette.successStatus.light.background.nsColor,
                    dark: SottoPalette.successStatus.dark.background.nsColor
                ),
                warning: Color(red: 0.90, green: 0.58, blue: 0.12),
                warningForeground: dynamicColor(
                    light: SottoPalette.warningStatus.light.foreground.nsColor,
                    dark: SottoPalette.warningStatus.dark.foreground.nsColor
                ),
                warningBackground: dynamicColor(
                    light: SottoPalette.warningStatus.light.background.nsColor,
                    dark: SottoPalette.warningStatus.dark.background.nsColor
                ),
                destructive: SottoPalette.destructiveAction.background.color,
                destructiveButtonForeground: SottoPalette.destructiveAction.foreground.color,
                destructiveForeground: dynamicColor(
                    light: SottoPalette.destructiveStatus.light.foreground.nsColor,
                    dark: SottoPalette.destructiveStatus.dark.foreground.nsColor
                ),
                destructiveBackground: dynamicColor(
                    light: SottoPalette.destructiveStatus.light.background.nsColor,
                    dark: SottoPalette.destructiveStatus.dark.background.nsColor
                )
            )
        )
    }

    public func withAccent(_ accent: Color, foreground: Color = .white) -> SottoTheme {
        var copy = self
        copy.colors.accent = accent
        copy.colors.accentForeground = foreground
        return copy
    }
}

private func dynamicColor(light: NSColor, dark: NSColor) -> Color {
    Color(
        nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        }
    )
}

private struct SottoThemeKey: EnvironmentKey {
    static let defaultValue = SottoTheme.standard
}

public extension EnvironmentValues {
    var sottoTheme: SottoTheme {
        get { self[SottoThemeKey.self] }
        set { self[SottoThemeKey.self] = newValue }
    }
}

public extension View {
    func sottoTheme(_ theme: SottoTheme) -> some View {
        environment(\.sottoTheme, theme)
            .tint(theme.colors.accent)
    }
}
