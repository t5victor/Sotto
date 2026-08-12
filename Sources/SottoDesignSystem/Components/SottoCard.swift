import SwiftUI

public enum SottoCardStyle: Sendable {
    case standard
    case raised
    case muted
}

public struct SottoCard<Content: View>: View {
    @Environment(\.sottoTheme) private var theme

    private let style: SottoCardStyle
    private let contentPadding: CGFloat?
    private let content: Content

    public init(
        style: SottoCardStyle = .standard,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.contentPadding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(contentPadding ?? theme.spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous)
                    .strokeBorder(theme.colors.border.opacity(style == .muted ? 0.55 : 1))
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous))
            .shadow(
                color: style == .raised ? Color.black.opacity(0.08) : .clear,
                radius: style == .raised ? 14 : 0,
                y: style == .raised ? 6 : 0
            )
    }

    private var backgroundColor: Color {
        switch style {
        case .standard: theme.colors.surface
        case .raised: theme.colors.raisedSurface
        case .muted: theme.colors.mutedSurface
        }
    }
}

