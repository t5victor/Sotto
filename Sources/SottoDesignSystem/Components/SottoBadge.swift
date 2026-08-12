import SwiftUI

public enum SottoBadgeTone: Sendable {
    case neutral
    case accent
    case success
    case warning
    case destructive
}

public struct SottoBadge: View {
    @Environment(\.sottoTheme) private var theme

    private let text: String
    private let systemImage: String?
    private let tone: SottoBadgeTone

    public init(
        _ text: String,
        systemImage: String? = nil,
        tone: SottoBadgeTone = .neutral
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
        }
        .font(theme.typography.caption)
        .foregroundStyle(toneForeground)
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(toneBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var toneForeground: Color {
        switch tone {
        case .neutral: theme.colors.mutedForeground
        case .accent: theme.colors.accentForeground
        case .success: theme.colors.successForeground
        case .warning: theme.colors.warningForeground
        case .destructive: theme.colors.destructiveForeground
        }
    }

    private var toneBackground: Color {
        switch tone {
        case .neutral: theme.colors.mutedSurface
        case .accent: theme.colors.accent
        case .success: theme.colors.successBackground
        case .warning: theme.colors.warningBackground
        case .destructive: theme.colors.destructiveBackground
        }
    }
}
