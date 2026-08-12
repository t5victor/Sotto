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
