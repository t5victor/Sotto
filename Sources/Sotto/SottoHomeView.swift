import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoHomeView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SottoReveal {
                    SottoPageHeader(
                        title: SottoLocalization.string("home.title"),
                        description: SottoLocalization.string("home.description")
                    )
                }

                if case .failed(let message) = model.dictationState {
                    SottoErrorBanner(message: message) {
                        model.dismissFailure()
                    }
                }
                if let notice = model.notice {
                    SottoNoticeBanner(message: notice) {
                        model.dismissNotice()
                    }
                }

                SottoReveal(delay: 0.04) {
                    dictationCard
                }

                SottoReveal(delay: 0.08) {
                    behaviorCard
                }

                if let first = model.history.first {
                    SottoReveal(delay: 0.12) {
                        recentCard(first)
                    }
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
        .background(theme.colors.surface)
    }

    private var dictationCard: some View {
        SottoCard(style: .raised, padding: 20) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    Text(dictationTitle)
                        .font(theme.typography.cardTitle)
                        .tracking(-0.22)
                        .foregroundStyle(theme.colors.foreground)

                    Text(dictationDescription)
                        .font(theme.typography.body)
                        .tracking(theme.typography.tracking)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: theme.spacing.sm) {
                        Button(primaryActionTitle) {
                            performPrimaryAction()
                        }
                        .buttonStyle(.sotto(model.isListening ? .secondary : .primary))
                        .disabled(primaryActionDisabled)

                        SottoShortcutKey(model.preferences.shortcut.localizedDisplayName)
                    }
                }

                Spacer(minLength: theme.spacing.xl)

                dictationActivity
            }
        }
    }

    @ViewBuilder
    private var dictationActivity: some View {
        switch model.dictationState {
        case .preparing:
            SottoActivityLabel(SottoLocalization.string("home.activity.preparing"))
        case .listening:
            SottoRecordingPill(state: .listening, level: model.audioLevel)
        case .transcribing:
            SottoActivityLabel(SottoLocalization.string("home.activity.transcribing"))
        case .inserting:
            SottoActivityLabel(SottoLocalization.string("home.activity.inserting"))
        default: EmptyView()
        }
    }

    private var behaviorCard: some View {
        SottoCard {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                SottoSectionHeader(
                    SottoLocalization.string("home.section.text"),
                    description: SottoLocalization.string("home.section.text_description")
                )
                SottoDivider()
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

    private func recentCard(_ record: TranscriptionRecord) -> some View {
        SottoCard(style: .muted) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack {
                    SottoSectionHeader(SottoLocalization.string("home.last_dictation"))
                    Spacer()
                    Button {
                        model.copyToPasteboard(record.text)
                    } label: {
                        SottoIcon("doc.on.doc", size: 13)
                    }
                    .buttonStyle(.sotto(.ghost, size: .small))
                    .help(SottoLocalization.string("common.copy"))
                }
                Text(record.text)
                    .font(theme.typography.body)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.foreground)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
    }

    private var dictationTitle: String {
        switch model.dictationState {
        case .idle:
            model.modelState.isReady
                ? SottoLocalization.string("home.dictation.ready")
                : SottoLocalization.string("home.dictation.prepare")
        case .preparing: SottoLocalization.string("home.dictation.preparing")
        case .listening: SottoLocalization.string("home.dictation.listening")
        case .transcribing: SottoLocalization.string("home.dictation.transcribing")
        case .inserting: SottoLocalization.string("home.dictation.inserting")
        case .completed: SottoLocalization.string("home.dictation.completed")
        case .failed: SottoLocalization.string("home.dictation.failed")
        }
    }

    private var dictationDescription: String {
        if model.modelState.isReady {
            return model.preferences.holdToTalk
                ? SottoLocalization.format(
                    "home.dictation.hold_description",
                    model.preferences.shortcut.localizedDisplayName
                )
                : SottoLocalization.format(
                    "home.dictation.toggle_description",
                    model.preferences.shortcut.localizedDisplayName
                )
        }
        return model.modelState.detail
    }

    private var primaryActionTitle: String {
        if model.isListening { return SottoLocalization.string("home.action.stop") }
        if model.dictationState.canCancel { return SottoLocalization.string("home.action.cancel") }
        if model.modelState.isReady { return SottoLocalization.string("common.start_dictation") }
        if case .downloading = model.modelState { return SottoLocalization.string("home.action.downloading") }
        if case .loading = model.modelState { return SottoLocalization.string("home.action.loading") }
        if case .validating = model.modelState { return SottoLocalization.string("home.action.validating") }
        if case .failed = model.modelState { return SottoLocalization.string("common.reinstall_model") }
        return SottoLocalization.string("common.install_model")
    }

    private var primaryActionDisabled: Bool {
        if model.dictationState.canCancel { return false }
        return switch model.modelState {
        case .notInstalled, .failed: false
        case .ready: false
        default: true
        }
    }

    private func performPrimaryAction() {
        if model.dictationState.canCancel {
            model.toggleDictation()
        } else if case .failed = model.modelState {
            model.reinstallModel()
        } else if model.modelState.isInstalled {
            model.toggleDictation()
        } else {
            model.installModel()
        }
    }
}

struct SottoPageHeader: View {
    @Environment(\.sottoTheme) private var theme
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
                .font(theme.typography.pageTitle)
                .tracking(-0.42)
                .foregroundStyle(theme.colors.foreground)
            Text(description)
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.mutedForeground)
        }
    }
}

private struct SottoErrorBanner: View {
    @Environment(\.sottoTheme) private var theme
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            SottoIcon("exclamationmark.triangle", size: 14)
                .foregroundStyle(theme.colors.destructiveForeground)
            Text(message)
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.foreground)
            Spacer()
            Button(SottoLocalization.string("common.close"), action: dismiss)
                .buttonStyle(.sotto(.ghost, size: .small))
        }
        .padding(theme.spacing.md)
        .background(theme.colors.destructiveBackground)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.medium)
                .strokeBorder(theme.colors.destructive.opacity(0.24))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct SottoNoticeBanner: View {
    @Environment(\.sottoTheme) private var theme
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            SottoIcon("info.circle", size: 14)
                .foregroundStyle(theme.colors.warningForeground)
            Text(message)
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.foreground)
            Spacer()
            Button(SottoLocalization.string("common.close"), action: dismiss)
                .buttonStyle(.sotto(.ghost, size: .small))
        }
        .padding(theme.spacing.md)
        .background(theme.colors.warningBackground)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.medium)
                .strokeBorder(theme.colors.warning.opacity(0.24))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct SottoShortcutKey: View {
    @Environment(\.sottoTheme) private var theme
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(theme.typography.mono)
            .foregroundStyle(theme.colors.mutedForeground)
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(theme.colors.field)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                    .strokeBorder(theme.colors.border)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
    }
}
