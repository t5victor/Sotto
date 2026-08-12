import SwiftUI

public struct SottoSectionHeader: View {
    @Environment(\.sottoTheme) private var theme

    private let title: String
    private let description: String?

    public init(_ title: String, description: String? = nil) {
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
                .font(theme.typography.sectionTitle)
                .foregroundStyle(theme.colors.foreground)

            if let description {
                Text(description)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

