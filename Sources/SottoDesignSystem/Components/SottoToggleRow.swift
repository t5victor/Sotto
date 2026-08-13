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
                SottoIcon(systemImage, size: 13, weight: .medium)
                    .foregroundStyle(theme.colors.subtleForeground)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.foreground)

                if let description {
                    Text(description)
                        .font(theme.typography.body)
                        .tracking(theme.typography.tracking)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: theme.spacing.lg)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.sotto)
        }
        .contentShape(Rectangle())
    }
}
