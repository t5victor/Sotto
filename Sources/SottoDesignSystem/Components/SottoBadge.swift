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
                SottoIcon(systemImage, size: 11, weight: .medium)
            }
            Text(text)
        }
        .font(theme.typography.caption)
        .tracking(theme.typography.tracking)
        .foregroundStyle(toneForeground)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(toneBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var toneForeground: Color {
        switch tone {
        case .neutral: theme.colors.mutedForeground
        case .accent: theme.colors.foreground
        case .success: theme.colors.successForeground
        case .warning: theme.colors.warningForeground
        case .destructive: theme.colors.destructiveForeground
        }
    }

    private var toneBackground: Color {
        switch tone {
        case .neutral: .clear
        case .accent: theme.colors.accentTint
        case .success: theme.colors.successBackground
        case .warning: theme.colors.warningBackground
        case .destructive: theme.colors.destructiveBackground
        }
    }

}
