import SwiftUI

public enum SottoPermissionState: Sendable {
    case granted
    case required
    case unavailable
}

public struct SottoPermissionRow: View {
    @Environment(\.sottoTheme) private var theme

    private let title: String
    private let description: String
    private let systemImage: String
    private let state: SottoPermissionState
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        _ title: String,
        description: String,
        systemImage: String,
        state: SottoPermissionState,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.state = state
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(width: 32, height: 32)
                .background(theme.colors.mutedSurface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.foreground)
                Text(description)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
            }

            Spacer(minLength: theme.spacing.md)

            SottoBadge(stateLabel, systemImage: stateIcon, tone: stateTone)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.sotto(.secondary, size: .small))
            }
        }
    }

    private var stateLabel: String {
        switch state {
        case .granted: "Concedido"
        case .required: "Necesario"
        case .unavailable: "No disponible"
        }
    }

    private var stateIcon: String {
        switch state {
        case .granted: "checkmark.circle.fill"
        case .required: "exclamationmark.circle.fill"
        case .unavailable: "minus.circle.fill"
        }
    }

    private var stateTone: SottoBadgeTone {
        switch state {
        case .granted: .success
        case .required: .warning
        case .unavailable: .neutral
        }
    }
}

