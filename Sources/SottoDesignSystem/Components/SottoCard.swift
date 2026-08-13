import SwiftUI

public enum SottoCardStyle: Sendable {
    case standard
    case raised
    case muted
}

public struct SottoCard<Content: View>: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

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
            .padding(contentPadding ?? theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous)
                    .strokeBorder(borderColor)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous))
            .shadow(
                color: style == .raised ? Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05) : .clear,
                radius: style == .raised ? 6 : 0,
                y: style == .raised ? 2 : 0
            )
    }

    private var backgroundColor: Color {
        switch style {
        case .standard: theme.colors.surface
        case .raised: theme.colors.raisedSurface
        case .muted: theme.colors.mutedSurface
        }
    }

    private var borderColor: Color {
        style == .raised ? theme.colors.strongBorder : theme.colors.border
    }
}
