import AppKit
import SwiftUI

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
        public var warning: Color
        public var destructive: Color

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
            warning: Color,
            destructive: Color
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
            self.warning = warning
            self.destructive = destructive
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
                accent: Color(red: 0.45, green: 0.34, blue: 0.95),
                accentForeground: .white,
                success: Color(red: 0.18, green: 0.64, blue: 0.39),
                warning: Color(red: 0.90, green: 0.58, blue: 0.12),
                destructive: Color(red: 0.88, green: 0.25, blue: 0.28)
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
