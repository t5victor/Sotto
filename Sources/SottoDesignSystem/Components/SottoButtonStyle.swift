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
        SottoButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            isEnabled: isEnabled,
            reduceMotion: reduceMotion,
            theme: theme,
            variant: variant,
            expands: expands,
            horizontalPadding: horizontalPadding,
            controlHeight: controlHeight
        )
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

private struct SottoButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let isEnabled: Bool
    let reduceMotion: Bool
    let theme: SottoTheme
    let variant: SottoButtonVariant
    let expands: Bool
    let horizontalPadding: CGFloat
    let controlHeight: CGFloat

    @State private var isHovered = false

    var body: some View {
        label
            .font(theme.typography.label)
            .tracking(theme.typography.tracking)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil, minHeight: controlHeight)
            .background(backgroundColor)
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: variant == .ghost ? 0 : 1)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.fast),
                value: isPressed
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: theme.motion.fast),
                value: isHovered
            )
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: theme.colors.accentForeground
        case .destructive: theme.colors.destructiveButtonForeground
        case .secondary, .ghost: theme.colors.foreground
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            isPressed || isHovered ? theme.colors.accentInk : theme.colors.actionBackground
        case .secondary:
            isPressed || isHovered ? theme.colors.hoverStrong : theme.colors.field
        case .ghost:
            isPressed || isHovered ? theme.colors.hover : .clear
        case .destructive:
            isPressed ? theme.colors.destructive.opacity(0.82) : theme.colors.destructive
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary: .clear
        case .secondary: theme.colors.strongBorder
        case .destructive: .clear
        case .ghost: .clear
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
