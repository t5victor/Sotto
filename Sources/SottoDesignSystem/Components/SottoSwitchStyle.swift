import SwiftUI

public struct SottoSwitchStyle: ToggleStyle {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? theme.colors.actionBackground : theme.colors.field)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                configuration.isOn ? theme.colors.accentInk : theme.colors.strongBorder
                            )
                    }

                Circle()
                    .fill(configuration.isOn ? theme.colors.accentForeground : theme.colors.mutedForeground)
                    .frame(width: 13, height: 13)
                    .padding(3)
                    .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
            }
            .frame(width: 32, height: 19)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: configuration.isOn
        )
    }
}

public extension ToggleStyle where Self == SottoSwitchStyle {
    static var sotto: SottoSwitchStyle { SottoSwitchStyle() }
}
