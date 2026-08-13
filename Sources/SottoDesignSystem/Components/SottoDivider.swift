import SwiftUI

public struct SottoDivider: View {
    @Environment(\.sottoTheme) private var theme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(theme.colors.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
