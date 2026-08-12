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
