import SwiftUI

public enum SottoButtonVariant: String, CaseIterable, Sendable {
    case primary
    case secondary
    case ghost
    case destructive
}

public enum SottoButtonSize: String, CaseIterable, Sendable {
    case small
    case regular
    case large
}

public struct SottoButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sottoTheme) private var theme

    private let variant: SottoButtonVariant
    private let size: SottoButtonSize
    private let expands: Bool

    public init(
        _ variant: SottoButtonVariant = .primary,
        size: SottoButtonSize = .regular,
        expands: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.expands = expands
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.label)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: controlHeight)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.78 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            .opacity(isEnabled ? 1 : 0.48)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: theme.motion.fast),
                value: configuration.isPressed
            )
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            theme.colors.accentForeground
        case .destructive:
            theme.colors.destructiveButtonForeground
        case .secondary, .ghost:
            theme.colors.foreground
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            theme.colors.accent
        case .secondary:
            theme.colors.raisedSurface
        case .ghost:
            .clear
        case .destructive:
            theme.colors.destructive
        }
    }

    private var borderColor: Color {
        variant == .secondary ? theme.colors.border : .clear
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: theme.spacing.sm
        case .regular: theme.spacing.md
        case .large: theme.spacing.lg
        }
    }

    private var controlHeight: CGFloat {
        switch size {
        case .small: theme.controlHeights.small
        case .regular: theme.controlHeights.regular
        case .large: theme.controlHeights.large
        }
    }
}

public extension ButtonStyle where Self == SottoButtonStyle {
    static func sotto(
        _ variant: SottoButtonVariant = .primary,
        size: SottoButtonSize = .regular,
        expands: Bool = false
    ) -> SottoButtonStyle {
        SottoButtonStyle(variant, size: size, expands: expands)
    }
}
