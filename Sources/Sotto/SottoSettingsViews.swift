import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoModelsView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var confirmsModelDeletion = false
    @State private var confirmsModelRepair = false

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.models.title"),
            description: SottoLocalization.string("settings.models.description")
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("waveform", size: 17)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text(SottoLocalization.string("settings.models.section_title"))
                                .font(theme.typography.sectionTitle)
                            Text(SottoLocalization.string("settings.models.section_description"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                    }

                    SottoDivider()

                    modelControls

                    SottoDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(SottoLocalization.string("settings.models.language_title"))
                                .font(theme.typography.label)
                            Text(SottoLocalization.string("settings.models.language_description"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker(
                            SottoLocalization.string("settings.models.language_picker"),
                            selection: $model.preferences.language
                        ) {
                            ForEach(SottoLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 205)
                    }

                }
            }
        }
        .confirmationDialog(
            SottoLocalization.string("settings.models.delete_confirmation"),
            isPresented: $confirmsModelDeletion,
            titleVisibility: .visible
        ) {
            Button(SottoLocalization.string("common.remove_model"), role: .destructive) {
                model.deleteModel()
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(SottoLocalization.string("settings.models.delete_message"))
        }
        .confirmationDialog(
            SottoLocalization.string("settings.models.reinstall_confirmation"),
            isPresented: $confirmsModelRepair,
            titleVisibility: .visible
        ) {
            Button(SottoLocalization.string("common.reinstall_model"), role: .destructive) {
                model.reinstallModel()
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(SottoLocalization.string("settings.models.reinstall_message"))
        }
    }

    @ViewBuilder
    private var modelControls: some View {
        switch model.modelState {
        case .notInstalled:
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(model.modelState.detail)
                        .font(theme.typography.body)
                }
                Spacer()
                Button(SottoLocalization.string("common.install_model")) {
                    model.installModel()
                }
                .buttonStyle(.sotto())
            }

        case .failed:
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(model.modelState.detail)
                        .font(theme.typography.body)
                }
                Spacer()
                Button(SottoLocalization.string("common.reinstall_model")) {
                    confirmsModelRepair = true
                }
                .buttonStyle(.sotto())
            }

        case .downloading(let progress, let detail):
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack {
                    Text(detail)
                        .font(theme.typography.label)
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(theme.typography.caption.monospacedDigit())
                }
                ProgressView(value: progress)
                    .tint(theme.colors.accent)
                Button(SottoLocalization.string("common.cancel")) {
                    model.cancelModelDownload()
                }
                .buttonStyle(.sotto(.secondary, size: .small))
            }

        case .checking, .validating, .loading:
            SottoActivityLabel(model.modelState.detail)

        case .installed, .ready:
            HStack {
                Text(model.modelState.detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
                Spacer()
                Button(SottoLocalization.string("common.remove_model")) {
                    confirmsModelDeletion = true
                }
                .buttonStyle(.sotto(.destructive, size: .small))
                .disabled(model.isBusy)
            }
        }
    }
}

struct SottoVocabularyView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var spokenForm = ""
    @State private var replacement = ""

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.vocabulary.title"),
            description: SottoLocalization.string("settings.vocabulary.description")
        ) {
            SottoCard {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader(
                        SottoLocalization.string("settings.vocabulary.add_title"),
                        description: SottoLocalization.string("settings.vocabulary.add_description")
                    )
                    HStack(spacing: theme.spacing.sm) {
                        TextField(
                            SottoLocalization.string("settings.vocabulary.spoken_placeholder"),
                            text: $spokenForm
                        )
                            .textFieldStyle(.sotto)
                        SottoIcon("arrow.right", size: 13)
                            .foregroundStyle(theme.colors.subtleForeground)
                        TextField(
                            SottoLocalization.string("settings.vocabulary.replacement_placeholder"),
                            text: $replacement
                        )
                            .textFieldStyle(.sotto)
                        Button(SottoLocalization.string("common.add")) {
                            model.addVocabulary(spokenForm: spokenForm, replacement: replacement)
                            spokenForm = ""
                            replacement = ""
                        }
                        .buttonStyle(.sotto())
                        .disabled(spokenForm.trimmed.isEmpty || replacement.trimmed.isEmpty)
                    }

                    SottoDivider()

                    if model.vocabulary.isEmpty {
                        SottoEmptyState(
                            systemImage: "book.closed",
                            title: SottoLocalization.string("settings.vocabulary.empty_title"),
                            description: SottoLocalization.string("settings.vocabulary.empty_description")
                        )
                    } else {
                        ForEach(model.vocabulary) { entry in
                            HStack(spacing: theme.spacing.md) {
                                Text(entry.spokenForm)
                                    .font(theme.typography.body)
                                SottoIcon("arrow.right", size: 13)
                                    .foregroundStyle(theme.colors.subtleForeground)
                                Text(entry.replacement)
                                    .font(theme.typography.label)
                                Spacer()
                                Button {
                                    model.removeVocabulary(id: entry.id)
                                } label: {
                                    SottoIcon("trash", size: 13)
                                }
                                .buttonStyle(.sotto(.ghost, size: .small))
                                .help(SottoLocalization.string("settings.vocabulary.delete"))
                            }
                            if entry.id != model.vocabulary.last?.id { SottoDivider() }
                        }
                    }
                }
            }
        }
    }
}

struct SottoShortcutsView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.shortcuts.title"),
            description: SottoLocalization.string("settings.shortcuts.description")
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("command", size: 15)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(SottoLocalization.string("settings.shortcuts.global_title"))
                                .font(theme.typography.label)
                            Text(SottoLocalization.string("settings.shortcuts.global_description"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker(SottoLocalization.string("settings.shortcuts.picker"), selection: shortcutBinding) {
                            Text(SottoShortcut.defaultDictation.localizedDisplayName).tag(SottoShortcut.defaultDictation)
                            Text(
                                SottoShortcut(
                                    keyCode: 49,
                                    carbonModifiers: 6_144,
                                    displayName: "⌃ ⌥ Espacio"
                                ).localizedDisplayName
                            ).tag(
                                SottoShortcut(keyCode: 49, carbonModifiers: 6_144, displayName: "⌃ ⌥ Espacio")
                            )
                            Text(
                                SottoShortcut(
                                    keyCode: 49,
                                    carbonModifiers: 5_120,
                                    displayName: "⌃ ⇧ Espacio"
                                ).localizedDisplayName
                            ).tag(
                                SottoShortcut(keyCode: 49, carbonModifiers: 5_120, displayName: "⌃ ⇧ Espacio")
                            )
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    if let hotKeyError = model.hotKeyError {
                        Text(hotKeyError)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.destructiveForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SottoDivider()

                    SottoToggleRow(
                        SottoLocalization.string("settings.shortcuts.hold_title"),
                        description: SottoLocalization.string("settings.shortcuts.hold_description"),
                        systemImage: "hand.tap",
                        isOn: $model.preferences.holdToTalk
                    )
                    SottoDivider()
                    SottoToggleRow(
                        SottoLocalization.string("settings.shortcuts.sounds_title"),
                        description: SottoLocalization.string("settings.shortcuts.sounds_description"),
                        systemImage: "speaker.wave.2",
                        isOn: $model.preferences.playSounds
                    )
                    SottoDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(SottoLocalization.string("settings.shortcuts.limit_title"))
                                .font(theme.typography.label)
                            Text(SottoLocalization.string("settings.shortcuts.limit_description"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker(
                            SottoLocalization.string("settings.shortcuts.duration_picker"),
                            selection: $model.preferences.maximumRecordingDuration
                        ) {
                            Text(SottoLocalization.string("settings.shortcuts.duration.2")).tag(TimeInterval(120))
                            Text(SottoLocalization.string("settings.shortcuts.duration.5")).tag(TimeInterval(300))
                            Text(SottoLocalization.string("settings.shortcuts.duration.10")).tag(TimeInterval(600))
                            Text(SottoLocalization.string("settings.shortcuts.duration.30")).tag(TimeInterval(1_800))
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
            }
        }
    }

    private var shortcutBinding: Binding<SottoShortcut> {
        Binding(
            get: { model.preferences.shortcut },
            set: { model.updateShortcut($0) }
        )
    }
}

struct SottoTextView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("home.section.text"),
            description: SottoLocalization.string("home.section.text_description")
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    SottoToggleRow(
                        SottoLocalization.string("home.normalize.title"),
                        description: SottoLocalization.string("home.normalize.description"),
                        systemImage: "textformat",
                        isOn: $model.preferences.normalizeText
                    )
                    SottoDivider()
                    SottoToggleRow(
                        SottoLocalization.string("home.fillers.title"),
                        description: SottoLocalization.string("home.fillers.description"),
                        systemImage: "sparkles",
                        isOn: $model.preferences.removeFillers
                    )
                }
            }
        }
    }
}

struct SottoAppearanceView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.appearance.title"),
            description: SottoLocalization.string("settings.appearance.description")
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader(SottoLocalization.string("settings.appearance.accent"))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: theme.spacing.sm),
                            GridItem(.flexible(), spacing: theme.spacing.sm),
                        ],
                        spacing: theme.spacing.sm
                    ) {
                        ForEach(SottoAccent.allCases) { option in
                            paletteOption(option)
                        }
                    }

                }
            }
        }
    }

    private func paletteOption(_ option: SottoAccent) -> some View {
        let isSelected = model.preferences.accent == option
        let paletteColor = option.themePalette.background.color

        return Button {
            model.preferences.accent = option
        } label: {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack(spacing: theme.spacing.sm) {
                    Circle()
                        .fill(paletteColor)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(theme.colors.strongBorder.opacity(0.65))
                        }

                    Text(option.displayName)
                        .font(theme.typography.label)
                        .foregroundStyle(theme.colors.foreground)

                    Spacer(minLength: theme.spacing.xs)

                    if isSelected {
                        SottoIcon("checkmark.circle.fill", size: 15, weight: .medium)
                            .foregroundStyle(theme.colors.accent)
                    }
                }

                HStack(spacing: theme.spacing.xs) {
                    Capsule().fill(paletteColor)
                    Capsule().fill(paletteColor.opacity(0.62))
                    Capsule().fill(paletteColor.opacity(0.24))
                }
                .frame(height: 6)
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.colors.accentTint : theme.colors.field)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.colors.accent : theme.colors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SottoPrivacyView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.privacy.title"),
            description: SottoLocalization.string("settings.privacy.description")
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    SottoPermissionRow(
                        SottoLocalization.string("settings.privacy.microphone.title"),
                        description: SottoLocalization.string("settings.privacy.microphone.description"),
                        systemImage: "mic",
                        state: model.microphonePermission.designState,
                        actionTitle: model.microphonePermission == .notDetermined
                            ? SottoLocalization.string("common.allow")
                            : permissionAction(model.microphonePermission)
                    ) {
                        if model.microphonePermission == .notDetermined {
                            model.requestMicrophonePermission()
                        } else {
                            model.openMicrophoneSettings()
                        }
                    }
                    SottoDivider()
                    SottoPermissionRow(
                        SottoLocalization.string("settings.privacy.accessibility.title"),
                        description: SottoLocalization.string("settings.privacy.accessibility.description"),
                        systemImage: "accessibility",
                        state: model.accessibilityPermission.designState,
                        actionTitle: permissionAction(model.accessibilityPermission)
                    ) {
                        if model.accessibilityPermission == .granted {
                            model.openAccessibilitySettings()
                        } else {
                            model.requestAccessibilityPermission()
                        }
                    }
                    SottoDivider()
                    SottoToggleRow(
                        SottoLocalization.string("settings.privacy.insert.title"),
                        description: SottoLocalization.string("settings.privacy.insert.description"),
                        systemImage: "text.cursor",
                        isOn: $model.preferences.insertAutomatically
                    )
                    SottoDivider()
                    SottoToggleRow(
                        SottoLocalization.string("settings.privacy.history.title"),
                        description: SottoLocalization.string("settings.privacy.history.description"),
                        systemImage: "clock",
                        isOn: $model.preferences.keepHistory
                    )
                    SottoDivider()
                    SottoToggleRow(
                        SottoLocalization.string("settings.privacy.login.title"),
                        description: SottoLocalization.string("settings.privacy.login.description"),
                        systemImage: "power",
                        isOn: launchAtLoginBinding
                    )
                    if let message = model.launchAtLoginMessage {
                        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
                            Text(message)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.warningForeground)
                            Spacer()
                            Button(SottoLocalization.string("settings.privacy.open_login_items")) {
                                model.openLoginItemsSettings()
                            }
                            .buttonStyle(.sotto(.secondary, size: .small))
                        }
                    }
#if DEBUG
                    SottoDivider()
                    HStack(alignment: .center, spacing: theme.spacing.md) {
                        SottoIcon("arrow.counterclockwise", size: 13, weight: .medium)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(SottoLocalization.string("settings.privacy.development"))
                                .font(theme.typography.label)
                                .foregroundStyle(theme.colors.foreground)
                            Text(SottoLocalization.string("settings.privacy.development_description"))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }

                        Spacer(minLength: theme.spacing.lg)

                        Button(SottoLocalization.string("settings.privacy.repeat_onboarding")) {
                            model.resetOnboardingForDebug()
                        }
                        .buttonStyle(.sotto(.secondary, size: .small))
                    }
#endif
                }
            }
        }
    }

    private func permissionAction(_ status: SottoPermissionStatus) -> String? {
        status == .granted
            ? SottoLocalization.string("common.open_settings")
            : SottoLocalization.string("common.configure")
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }
}

struct SottoHistoryView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var confirmsHistoryDeletion = false

    var body: some View {
        SottoSettingsPage(
            title: SottoLocalization.string("settings.history.title"),
            description: SottoLocalization.string("settings.history.description")
        ) {
            if model.history.isEmpty {
                SottoCard {
                    SottoEmptyState(
                        systemImage: "clock",
                        title: SottoLocalization.string("settings.history.empty_title"),
                        description: SottoLocalization.string("settings.history.empty_description")
                    )
                }
            } else {
                HStack {
                    Text(
                        SottoLocalization.count(
                            "settings.history.count.one",
                            "settings.history.count.other",
                            model.history.count
                        )
                    )
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                    Spacer()
                    Button(SottoLocalization.string("settings.history.clear")) {
                        confirmsHistoryDeletion = true
                    }
                    .buttonStyle(.sotto(.destructive, size: .small))
                }

                LazyVStack(spacing: 0) {
                    ForEach(model.history) { record in
                        SottoTranscriptRow(record: record, model: model, projectID: nil)
                        if record.id != model.history.last?.id {
                            SottoDivider()
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            SottoLocalization.string("settings.history.clear_confirmation"),
            isPresented: $confirmsHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button(SottoLocalization.string("settings.history.clear"), role: .destructive) {
                model.clearHistory()
            }
            Button(SottoLocalization.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(SottoLocalization.string("settings.history.clear_message"))
        }
    }
}

struct SottoSettingsPage<Content: View>: View {
    @Environment(\.sottoTheme) private var theme
    let title: String
    let description: String
    @ViewBuilder let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SottoReveal {
                    SottoPageHeader(title: title, description: description)
                }

                SottoReveal(delay: 0.04) {
                    content
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
        .background(theme.colors.surface)
    }
}

struct SottoEmptyState: View {
    @Environment(\.sottoTheme) private var theme
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            SottoIcon(systemImage, size: 20)
                .foregroundStyle(theme.colors.subtleForeground)
            Text(title)
                .font(theme.typography.label)
                .tracking(theme.typography.tracking)
            Text(description)
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
