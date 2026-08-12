import SwiftUI

public struct SottoToggleRow: View {
    @Environment(\.sottoTheme) private var theme

    @Binding private var isOn: Bool
    private let title: String
    private let description: String?
    private let systemImage: String?

    public init(
        _ title: String,
        description: String? = nil,
        systemImage: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 30, height: 30)
                    .background(theme.colors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.foreground)

                if let description {
                    Text(description)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: theme.spacing.lg)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .contentShape(Rectangle())
    }
}

