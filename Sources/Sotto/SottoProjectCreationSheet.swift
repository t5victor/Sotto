import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoProjectCreationSheet: View {
    @Binding var name: String
    @Binding var icon: String
    @Binding var accent: SottoAccent
    let onCancel: () -> Void
    let onCreate: (String, String, SottoAccent) -> Void

    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isNameFocused: Bool

    private let iconOptions = [
        "folder",
        "music.note",
        "airplane",
        "briefcase",
        "book",
        "terminal",
        "lightbulb",
        "star",
        "globe",
        "bolt",
        "hammer",
        "heart",
    ]

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            projectNameField
                .padding(.top, theme.spacing.lg)

            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text(SottoLocalization.string("project.icon_and_color"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.foreground)

                iconPicker
                colorPicker
            }
            .padding(.top, theme.spacing.xl)

            Spacer(minLength: theme.spacing.lg)

            footer
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.surface)
        .onAppear {
            isNameFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(SottoLocalization.string("project.create_title"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.colors.foreground)

            Spacer(minLength: theme.spacing.md)

            Button(action: onCancel) {
                SottoIcon("xmark", size: 15, weight: .regular)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SottoProjectPickerButtonStyle())
            .help(SottoLocalization.string("common.close"))
            .accessibilityLabel(SottoLocalization.string("common.close"))
        }
    }

    private var projectNameField: some View {
        HStack(spacing: 0) {
            SottoIcon("folder", size: 18, weight: .regular)
                .foregroundStyle(theme.colors.foreground.opacity(0.82))
                .frame(width: 46, height: 44)

            Rectangle()
                .fill(isNameFocused ? theme.colors.accent : theme.colors.border)
                .frame(width: 1, height: 44)

            TextField(SottoLocalization.string("project.name_placeholder"), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(theme.colors.foreground)
                .focused($isNameFocused)
                .padding(.horizontal, theme.spacing.md)
                .onSubmit {
                    guard canCreate else { return }
                    onCreate(name, icon, accent)
                }
        }
        .frame(height: 44)
        .background(theme.colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                .strokeBorder(
                    isNameFocused ? theme.colors.accent : theme.colors.border,
                    lineWidth: isNameFocused ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
    }

    private var iconPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(34), spacing: theme.spacing.sm), count: 6),
            alignment: .leading,
            spacing: theme.spacing.sm
        ) {
            ForEach(iconOptions, id: \.self) { option in
                Button {
                    icon = option
                } label: {
                    SottoIcon(option, size: 17, weight: .regular)
                        .foregroundStyle(icon == option ? accent.color : theme.colors.mutedForeground)
                        .frame(width: 34, height: 34)
                        .background(icon == option ? theme.colors.accentTint : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
                }
                .buttonStyle(SottoProjectPickerButtonStyle())
                .accessibilityLabel(SottoLocalization.format("project.icon_label", option))
                .accessibilityAddTraits(icon == option ? .isSelected : [])
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: theme.spacing.md) {
            Text(SottoLocalization.string("project.color"))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(theme.colors.mutedForeground)

            ForEach(SottoAccent.allCases) { option in
                Button {
                    accent = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    accent == option ? theme.colors.foreground : .clear,
                                    lineWidth: 2
                                )
                                .padding(-4)
                        }
                }
                .buttonStyle(SottoProjectPickerButtonStyle())
                .accessibilityLabel(option.displayName)
                .accessibilityAddTraits(accent == option ? .isSelected : [])
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer(minLength: theme.spacing.md)

            Button(SottoLocalization.string("common.cancel"), action: onCancel)
                .buttonStyle(.sotto(.ghost, size: .regular))

            Button(SottoLocalization.string("project.create_title")) {
                onCreate(name, icon, accent)
            }
            .buttonStyle(.sotto(.primary, size: .regular))
            .disabled(!canCreate)
        }
    }
}

private struct SottoProjectPickerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private extension SottoAccent {
    var color: Color {
        switch self {
        case .violet: .purple
        case .blue: .blue
        case .coral: .orange
        case .green: .green
        }
    }
}
