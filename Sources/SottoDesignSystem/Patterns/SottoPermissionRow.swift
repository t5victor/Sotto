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
            SottoIcon(systemImage, size: 14)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.foreground)
                Text(description)
                    .font(theme.typography.body)
                    .tracking(theme.typography.tracking)
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
        case .granted: "checkmark"
        case .required: "exclamationmark"
        case .unavailable: "minus"
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
