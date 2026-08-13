import AppKit
import SwiftUI

public struct SottoSRGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(hex: Int, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    fileprivate var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
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
    // Beautiful UI reference palette. Keeping the measured values here makes
    // the visual language inspectable and replaceable like shadcn tokens.
    public enum Light {
        public static let page = SottoSRGB(hex: 0xFAFAFB)
        public static let canvas = SottoSRGB(hex: 0xF1F2F3)
        public static let surface = SottoSRGB(hex: 0xFFFFFF)
        public static let inset = SottoSRGB(hex: 0xF7F8F9)
        public static let field = SottoSRGB(hex: 0xF2F2F3)
        public static let hover = SottoSRGB(hex: 0xF4F5F6)
        public static let hoverStrong = SottoSRGB(hex: 0xE7E9EB)
        public static let line = SottoSRGB(hex: 0xECEDEF)
        public static let lineStrong = SottoSRGB(hex: 0xE0E2E5)
        public static let ink = SottoSRGB(hex: 0x1F2124)
        public static let ink2 = SottoSRGB(hex: 0x62656B)
        public static let ink3 = SottoSRGB(hex: 0x9A9DA3)
        public static let accent = SottoSRGB(hex: 0x0285FF)
        public static let accentInk = SottoSRGB(hex: 0x0170DD)
        public static let accentTint = SottoSRGB(hex: 0xE9F3FF)
        public static let green = SottoSRGB(hex: 0x189A4D)
        public static let greenTint = SottoSRGB(hex: 0xE8F5ED)
        public static let orange = SottoSRGB(hex: 0xEF720C)
        public static let orangeTint = SottoSRGB(hex: 0xFDF1E5)
        public static let red = SottoSRGB(hex: 0xE3474C)
        public static let redTint = SottoSRGB(hex: 0xFCECEC)
        public static let overlay = SottoSRGB(hex: 0x25272B)
        public static let overlayLine = SottoSRGB(hex: 0x3A3C40)
        public static let overlayInk = SottoSRGB(hex: 0xF6F7F8)
        public static let overlayMuted = SottoSRGB(hex: 0xA5A8AD)
    }

    public enum Dark {
        public static let page = SottoSRGB(hex: 0x17181A)
        public static let canvas = SottoSRGB(hex: 0x1C1D1F)
        public static let surface = SottoSRGB(hex: 0x232427)
        public static let inset = SottoSRGB(hex: 0x1F2022)
        public static let field = SottoSRGB(hex: 0x2B2C2F)
        public static let hover = SottoSRGB(hex: 0x2A2B2E)
        public static let hoverStrong = SottoSRGB(hex: 0x313236)
        public static let line = SottoSRGB(hex: 0x2E3033)
        public static let lineStrong = SottoSRGB(hex: 0x3A3C40)
        public static let ink = SottoSRGB(hex: 0xF2F3F4)
        public static let ink2 = SottoSRGB(hex: 0xA5A8AD)
        public static let ink3 = SottoSRGB(hex: 0x6C6F75)
        public static let accent = SottoSRGB(hex: 0x3D9AFF)
        public static let accentInk = SottoSRGB(hex: 0x7EC0FF)
        public static let accentTint = SottoSRGB(hex: 0x3D9AFF, alpha: 0x29 / 255.0)
        public static let green = SottoSRGB(hex: 0x3DBB72)
        public static let greenTint = SottoSRGB(hex: 0x3DBB72, alpha: 0x24 / 255.0)
        public static let orange = SottoSRGB(hex: 0xF68F3C)
        public static let orangeTint = SottoSRGB(hex: 0xF68F3C, alpha: 0x24 / 255.0)
        public static let red = SottoSRGB(hex: 0xEE5C61)
        public static let redTint = SottoSRGB(hex: 0xEE5C61, alpha: 0x24 / 255.0)
        public static let overlay = SottoSRGB(hex: 0x111214)
        public static let overlayLine = SottoSRGB(hex: 0x2E3033)
        public static let overlayInk = SottoSRGB(hex: 0xF2F3F4)
        public static let overlayMuted = SottoSRGB(hex: 0xA5A8AD)
    }

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
            background: Light.greenTint,
            foreground: SottoSRGB(red: 17.0 / 255, green: 96.0 / 255, blue: 51.0 / 255)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(hex: 0x27392E),
            foreground: SottoSRGB(red: 169.0 / 255, green: 239.0 / 255, blue: 199.0 / 255)
        )
    )
    public static let warningStatus = SottoAdaptiveColorPair(
        light: SottoColorPair(
            background: Light.orangeTint,
            foreground: SottoSRGB(red: 107.0 / 255, green: 71.0 / 255, blue: 0)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(hex: 0x403127),
            foreground: SottoSRGB(red: 255.0 / 255, green: 216.0 / 255, blue: 135.0 / 255)
        )
    )
    public static let destructiveStatus = SottoAdaptiveColorPair(
        light: SottoColorPair(
            background: Light.redTint,
            foreground: SottoSRGB(red: 143.0 / 255, green: 29.0 / 255, blue: 40.0 / 255)
        ),
        dark: SottoColorPair(
            background: SottoSRGB(hex: 0x412B2F),
            foreground: SottoSRGB(red: 255.0 / 255, green: 185.0 / 255, blue: 191.0 / 255)
        )
    )
    public static let actionPairs = [
        SottoColorPair(
            background: Light.accentInk,
            foreground: SottoSRGB(hex: 0xFFFFFF)
        ),
        SottoColorPair(
            background: Dark.accentInk,
            foreground: Dark.page
        ),
        SottoColorPair(
            background: SottoSRGB(hex: 0xD63A40),
            foreground: SottoSRGB(hex: 0xFFFFFF)
        ),
        SottoColorPair(
            background: SottoSRGB(hex: 0xC42E37),
            foreground: SottoSRGB(hex: 0xFFFFFF)
        ),
    ]

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

    public static var accent: Color { adaptiveColor(light: Light.accent, dark: Dark.accent) }
    public static var accentInk: Color { adaptiveColor(light: Light.accentInk, dark: Dark.accentInk) }
    public static var accentTint: Color { adaptiveColor(light: Light.accentTint, dark: Dark.accentTint) }
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
        public var field: Color
        public var hover: Color
        public var hoverStrong: Color
        public var border: Color
        public var strongBorder: Color
        public var foreground: Color
        public var mutedForeground: Color
        public var subtleForeground: Color
        public var accent: Color
        public var accentInk: Color
        public var accentTint: Color
        public var actionBackground: Color
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
        public var overlay: Color
        public var overlayBorder: Color
        public var overlayForeground: Color
        public var overlayMutedForeground: Color

        public init(
            canvas: Color,
            surface: Color,
            raisedSurface: Color,
            mutedSurface: Color,
            field: Color,
            hover: Color,
            hoverStrong: Color,
            border: Color,
            strongBorder: Color,
            foreground: Color,
            mutedForeground: Color,
            subtleForeground: Color,
            accent: Color,
            accentInk: Color,
            accentTint: Color,
            actionBackground: Color,
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
            destructiveBackground: Color,
            overlay: Color,
            overlayBorder: Color,
            overlayForeground: Color,
            overlayMutedForeground: Color
        ) {
            self.canvas = canvas
            self.surface = surface
            self.raisedSurface = raisedSurface
            self.mutedSurface = mutedSurface
            self.field = field
            self.hover = hover
            self.hoverStrong = hoverStrong
            self.border = border
            self.strongBorder = strongBorder
            self.foreground = foreground
            self.mutedForeground = mutedForeground
            self.subtleForeground = subtleForeground
            self.accent = accent
            self.accentInk = accentInk
            self.accentTint = accentTint
            self.actionBackground = actionBackground
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
            self.overlay = overlay
            self.overlayBorder = overlayBorder
            self.overlayForeground = overlayForeground
            self.overlayMutedForeground = overlayMutedForeground
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
            medium: CGFloat = 8,
            large: CGFloat = 10,
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

        public init(small: CGFloat = 28, regular: CGFloat = 32, large: CGFloat = 38) {
            self.small = small
            self.regular = regular
            self.large = large
        }
    }

    public struct Typography: Sendable {
        public var pageTitle: Font
        public var cardTitle: Font
        public var sectionTitle: Font
        public var body: Font
        public var label: Font
        public var caption: Font
        public var micro: Font
        public var mono: Font
        public var sidebarTitle: Font
        public var sidebarItem: Font
        public var sidebarAction: Font
        public var sidebarSection: Font
        public var sidebarSectionAction: Font
        public var sidebarMeta: Font
        public var tracking: CGFloat

        public init(
            pageTitle: Font = .custom("Inter", size: 20).weight(.semibold),
            cardTitle: Font = .custom("Inter", size: 17).weight(.semibold),
            sectionTitle: Font = .custom("Inter", size: 13).weight(.semibold),
            body: Font = .custom("Inter", size: 13),
            label: Font = .custom("Inter", size: 12.5).weight(.medium),
            caption: Font = .custom("Inter", size: 11.5).weight(.medium),
            micro: Font = .custom("Inter", size: 10.5).weight(.medium),
            mono: Font = .custom("JetBrains Mono", size: 10.5),
            sidebarTitle: Font = .system(size: 20, weight: .semibold),
            sidebarItem: Font = .system(size: 15.5, weight: .regular),
            sidebarAction: Font = .system(size: 15.5, weight: .regular),
            sidebarSection: Font = .system(size: 14, weight: .regular),
            sidebarSectionAction: Font = .system(size: 14, weight: .regular),
            sidebarMeta: Font = .system(size: 14, weight: .regular),
            tracking: CGFloat = -0.10
        ) {
            self.pageTitle = pageTitle
            self.cardTitle = cardTitle
            self.sectionTitle = sectionTitle
            self.body = body
            self.label = label
            self.caption = caption
            self.micro = micro
            self.mono = mono
            self.sidebarTitle = sidebarTitle
            self.sidebarItem = sidebarItem
            self.sidebarAction = sidebarAction
            self.sidebarSection = sidebarSection
            self.sidebarSectionAction = sidebarSectionAction
            self.sidebarMeta = sidebarMeta
            self.tracking = tracking
        }
    }

    public struct Motion: Equatable, Sendable {
        public var fast: Double
        public var regular: Double
        public var slow: Double
        public var reveal: Double

        public init(fast: Double = 0.10, regular: Double = 0.15, slow: Double = 0.25, reveal: Double = 0.35) {
            self.fast = fast
            self.regular = regular
            self.slow = slow
            self.reveal = reveal
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
                canvas: adaptiveColor(light: SottoPalette.Light.page, dark: SottoPalette.Dark.page),
                surface: adaptiveColor(light: SottoPalette.Light.surface, dark: SottoPalette.Dark.surface),
                raisedSurface: adaptiveColor(light: SottoPalette.Light.canvas, dark: SottoPalette.Dark.canvas),
                mutedSurface: adaptiveColor(light: SottoPalette.Light.inset, dark: SottoPalette.Dark.inset),
                field: adaptiveColor(light: SottoPalette.Light.field, dark: SottoPalette.Dark.field),
                hover: adaptiveColor(light: SottoPalette.Light.hover, dark: SottoPalette.Dark.hover),
                hoverStrong: adaptiveColor(light: SottoPalette.Light.hoverStrong, dark: SottoPalette.Dark.hoverStrong),
                border: adaptiveColor(light: SottoPalette.Light.line, dark: SottoPalette.Dark.line),
                strongBorder: adaptiveColor(light: SottoPalette.Light.lineStrong, dark: SottoPalette.Dark.lineStrong),
                foreground: adaptiveColor(light: SottoPalette.Light.ink, dark: SottoPalette.Dark.ink),
                mutedForeground: adaptiveColor(light: SottoPalette.Light.ink2, dark: SottoPalette.Dark.ink2),
                subtleForeground: adaptiveColor(light: SottoPalette.Light.ink3, dark: SottoPalette.Dark.ink3),
                accent: SottoPalette.accent,
                accentInk: SottoPalette.accentInk,
                accentTint: SottoPalette.accentTint,
                actionBackground: SottoPalette.accentInk,
                accentForeground: adaptiveColor(
                    light: SottoSRGB(hex: 0xFFFFFF),
                    dark: SottoPalette.Dark.page
                ),
                success: adaptiveColor(light: SottoPalette.Light.green, dark: SottoPalette.Dark.green),
                successForeground: dynamicColor(
                    light: SottoPalette.successStatus.light.foreground.nsColor,
                    dark: SottoPalette.successStatus.dark.foreground.nsColor
                ),
                successBackground: dynamicColor(
                    light: SottoPalette.successStatus.light.background.nsColor,
                    dark: SottoPalette.successStatus.dark.background.nsColor
                ),
                warning: adaptiveColor(light: SottoPalette.Light.orange, dark: SottoPalette.Dark.orange),
                warningForeground: dynamicColor(
                    light: SottoPalette.warningStatus.light.foreground.nsColor,
                    dark: SottoPalette.warningStatus.dark.foreground.nsColor
                ),
                warningBackground: dynamicColor(
                    light: SottoPalette.warningStatus.light.background.nsColor,
                    dark: SottoPalette.warningStatus.dark.background.nsColor
                ),
                destructive: adaptiveColor(
                    light: SottoSRGB(hex: 0xD63A40),
                    dark: SottoSRGB(hex: 0xC42E37)
                ),
                destructiveButtonForeground: adaptiveColor(
                    light: SottoSRGB(hex: 0xFFFFFF),
                    dark: SottoSRGB(hex: 0xFFFFFF)
                ),
                destructiveForeground: dynamicColor(
                    light: SottoPalette.destructiveStatus.light.foreground.nsColor,
                    dark: SottoPalette.destructiveStatus.dark.foreground.nsColor
                ),
                destructiveBackground: dynamicColor(
                    light: SottoPalette.destructiveStatus.light.background.nsColor,
                    dark: SottoPalette.destructiveStatus.dark.background.nsColor
                ),
                overlay: adaptiveColor(light: SottoPalette.Light.overlay, dark: SottoPalette.Dark.overlay),
                overlayBorder: adaptiveColor(light: SottoPalette.Light.overlayLine, dark: SottoPalette.Dark.overlayLine),
                overlayForeground: adaptiveColor(light: SottoPalette.Light.overlayInk, dark: SottoPalette.Dark.overlayInk),
                overlayMutedForeground: adaptiveColor(light: SottoPalette.Light.overlayMuted, dark: SottoPalette.Dark.overlayMuted)
            )
        )
    }

    public func withAccent(_ accent: Color, foreground: Color = .white) -> SottoTheme {
        var copy = self
        copy.colors.accent = accent
        copy.colors.accentForeground = foreground
        copy.colors.accentInk = accent
        copy.colors.accentTint = accent.opacity(0.14)
        copy.colors.actionBackground = accent
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

private func adaptiveColor(light: SottoSRGB, dark: SottoSRGB) -> Color {
    dynamicColor(light: light.nsColor, dark: dark.nsColor)
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
