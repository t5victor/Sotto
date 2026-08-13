import SwiftUI

public struct SottoTextFieldStyle: TextFieldStyle {
    @Environment(\.sottoTheme) private var theme

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(theme.typography.body)
            .tracking(theme.typography.tracking)
            .foregroundStyle(theme.colors.foreground)
            .padding(.horizontal, 10)
            .frame(minHeight: theme.controlHeights.regular)
            .background(theme.colors.field)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                    .strokeBorder(theme.colors.border)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
    }
}

public extension TextFieldStyle where Self == SottoTextFieldStyle {
    static var sotto: SottoTextFieldStyle { SottoTextFieldStyle() }
}
