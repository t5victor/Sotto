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
        .foregroundStyle(toneColor)
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(toneColor.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var toneColor: Color {
        switch tone {
        case .neutral: theme.colors.mutedForeground
        case .accent: theme.colors.accent
        case .success: theme.colors.success
        case .warning: theme.colors.warning
        case .destructive: theme.colors.destructive
        }
    }
}

