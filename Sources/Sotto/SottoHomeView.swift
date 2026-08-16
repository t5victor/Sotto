import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoHomeView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    @State private var selectedVoiceStyle: SottoVoiceStyle = .informal

    var body: some View {
        GeometryReader { proxy in
            let metrics = SottoHomeLayoutMetrics(size: proxy.size)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    SottoReveal {
                        welcomeContent(metrics: metrics)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Color.clear
                        .frame(height: metrics.composerReserve)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomComposerArea(metrics: metrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.canvas)
        }
    }

    private func welcomeContent(metrics: SottoHomeLayoutMetrics) -> some View {
        VStack(spacing: theme.spacing.lg) {
            SottoWelcomeMark()

            Text(SottoLocalization.string("home.welcome_title"))
                .font(.system(size: metrics.titleSize, weight: .medium))
                .tracking(-0.72)
                .foregroundStyle(theme.colors.foreground)

            suggestionCards(metrics: metrics)
        }
        .frame(width: metrics.contentWidth)
    }

    private func suggestionCards(metrics: SottoHomeLayoutMetrics) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: metrics.cardSpacing),
                count: metrics.cardColumns
            ),
            spacing: metrics.cardSpacing
        ) {
            SottoHomeSuggestionCard(
                icon: "bubble.left",
                color: theme.colors.mutedForeground,
                title: SottoLocalization.string("home.suggestion.explore"),
                minHeight: metrics.cardHeight,
                isHighlighted: selectedVoiceStyle == .informal,
                action: { selectedVoiceStyle = .informal }
            )
            SottoHomeSuggestionCard(
                icon: "textformat",
                color: theme.colors.mutedForeground,
                title: SottoLocalization.string("home.suggestion.create"),
                minHeight: metrics.cardHeight,
                isHighlighted: selectedVoiceStyle == .formal,
                action: { selectedVoiceStyle = .formal }
            )
            SottoHomeSuggestionCard(
                icon: "list.bullet",
                color: theme.colors.mutedForeground,
                title: SottoLocalization.string("home.suggestion.review"),
                minHeight: metrics.cardHeight,
                isHighlighted: selectedVoiceStyle == .structured,
                action: { selectedVoiceStyle = .structured }
            )
            SottoHomeSuggestionCard(
                icon: "line.3.horizontal",
                color: theme.colors.mutedForeground,
                title: SottoLocalization.string("home.suggestion.fix"),
                minHeight: metrics.cardHeight,
                isHighlighted: selectedVoiceStyle == .messy,
                action: { selectedVoiceStyle = .messy }
            )
        }
        .frame(width: metrics.contentWidth)
    }

    private func bottomComposerArea(metrics: SottoHomeLayoutMetrics) -> some View {
        VStack(spacing: theme.spacing.sm) {
            if case .failed(let message) = model.dictationState {
                SottoErrorBanner(
                    message: message,
                    accept: model.canPastePendingTranscript ? { model.pastePendingTranscript() } : nil,
                    retry: model.canRetryDictation ? { model.retryFailedDictation() } : nil
                ) {
                    model.dismissFailure()
                }
                .frame(maxWidth: metrics.composerWidth)
            }

            if let notice = model.notice {
                SottoNoticeBanner(message: notice) {
                    model.dismissNotice()
                }
                .frame(maxWidth: metrics.composerWidth)
            }

            SottoReveal(delay: 0.04) {
                composerGrid(metrics: metrics)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, metrics.bottomInset)
    }

    private func composerGrid(metrics: SottoHomeLayoutMetrics) -> some View {
        composer(metrics: metrics)
            .frame(width: metrics.composerWidth)
            .frame(maxWidth: .infinity)
    }

    private func composer(metrics: SottoHomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: theme.spacing.md) {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(composerPrompt)
                        .font(.system(size: 14, weight: .regular))
                        .tracking(-0.18)
                        .foregroundStyle(composerPromptColor)

                    if shouldShowComposerHint {
                        Text(composerHint)
                            .font(theme.typography.caption)
                            .tracking(theme.typography.tracking)
                            .foregroundStyle(theme.colors.mutedForeground)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: theme.spacing.md)

                if model.isListening {
                    SottoRecordingPill(state: .listening, level: model.audioLevel)
                } else if case .transcribing = model.dictationState {
                    SottoRecordingPill(state: .transcribing)
                }
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.top, theme.spacing.md)

            Spacer(minLength: 0)

            HStack(spacing: theme.spacing.md) {
                Spacer(minLength: 0)

                SottoIcon("mic", size: 16, weight: .regular)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .accessibilityHidden(true)
                recordButton
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.bottom, theme.spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: metrics.composerHeight, alignment: .topLeading)
        .background(theme.colors.field)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.colors.strongBorder.opacity(0.72), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var recordButton: some View {
        Button(action: performPrimaryAction) {
            ZStack {
                Circle()
                    .fill(recordButtonBackground)
                SottoIcon(recordButtonIcon, size: 17, weight: .semibold)
                    .foregroundStyle(recordButtonForeground)
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(SottoRecordButtonStyle())
        .disabled(primaryActionDisabled)
        .help(primaryActionTitle)
        .accessibilityLabel(primaryActionTitle)
    }

    private var composerPrompt: String {
        switch model.dictationState {
        case .idle:
            model.modelState.isReady
                ? SottoLocalization.string("home.composer.placeholder")
                : model.modelState.detail
        case .preparing: SottoLocalization.string("home.dictation.preparing")
        case .listening: SottoLocalization.string("home.composer.listening")
        case .transcribing: SottoLocalization.string("home.composer.transcribing")
        case .inserting: SottoLocalization.string("home.composer.inserting")
        case .completed: SottoLocalization.string("home.dictation.completed")
        case .failed: SottoLocalization.string("home.dictation.failed")
        }
    }

    private var composerPromptColor: Color {
        switch model.dictationState {
        case .idle:
            model.modelState.isReady
                ? theme.colors.subtleForeground.opacity(0.82)
                : theme.colors.mutedForeground
        case .failed: theme.colors.destructiveForeground
        default: theme.colors.foreground
        }
    }

    private var shouldShowComposerHint: Bool {
        if case .idle = model.dictationState {
            return !model.modelState.isReady
        }
        return true
    }

    private var composerHint: String {
        switch model.dictationState {
        case .idle:
            model.modelState.isReady
                ? SottoLocalization.string("home.composer.ready_hint")
                : model.modelState.detail
        case .preparing, .listening:
            SottoLocalization.string("home.composer.listening_hint")
        case .transcribing:
            SottoLocalization.string("home.composer.transcribing_hint")
        case .inserting:
            SottoLocalization.string("home.composer.inserting_hint")
        case .completed:
            SottoLocalization.string("home.composer.completed_hint")
        case .failed:
            SottoLocalization.string("home.composer.failed_hint")
        }
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

    private var recordButtonIcon: String {
        if model.isListening { return "stop.fill" }
        if model.dictationState.canCancel { return "xmark" }
        if model.modelState.isReady { return "waveform" }
        if case .failed = model.modelState { return "arrow.clockwise" }
        return "arrow.down.circle.fill"
    }

    private var recordButtonBackground: Color {
        if model.isListening { return theme.colors.destructive }
        if model.dictationState.canCancel { return theme.colors.hoverStrong }
        if model.modelState.isReady { return theme.colors.accent }
        return theme.colors.field
    }

    private var recordButtonForeground: Color {
        if model.isListening { return theme.colors.destructiveButtonForeground }
        if model.modelState.isReady { return theme.colors.accentForeground }
        return theme.colors.foreground
    }

}

private enum SottoVoiceStyle: Hashable {
    case informal
    case formal
    case structured
    case messy
}

private struct SottoHomeLayoutMetrics {
    let size: CGSize

    var horizontalGutter: CGFloat {
        min(max(size.width * 0.04, 24), 48)
    }

    var contentWidth: CGFloat {
        let availableWidth = max(size.width - (horizontalGutter * 2), 280)
        let preferredWidth = min(max(size.width * 0.60, 520), 980)
        return min(preferredWidth, availableWidth)
    }

    /// The composer uses the same centered track as the hero.
    var composerWidth: CGFloat {
        contentWidth
    }

    var cardColumns: Int {
        contentWidth >= 720 ? 4 : 2
    }

    var cardSpacing: CGFloat {
        min(max(size.width * 0.012, 10), 14)
    }

    var titleSize: CGFloat {
        min(max(size.width * 0.022, 28), 34)
    }

    var cardHeight: CGFloat {
        min(max(size.height * 0.088, 96), 124)
    }

    var composerHeight: CGFloat {
        min(max(size.height * 0.080, 106), 124)
    }

    var bottomInset: CGFloat {
        min(max(size.height * 0.018, 24), 36)
    }

    var composerReserve: CGFloat {
        composerHeight + bottomInset
    }
}

private struct SottoWelcomeMark: View {
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoIcon("mic", size: 26, weight: .regular)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
    }
}

private struct SottoHomeSuggestionCard: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false
    @State private var isHovered = false

    let icon: String
    let color: Color
    let title: String
    let minHeight: CGFloat
    var isHighlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                SottoIcon(icon, size: 15, weight: .regular)
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.16)
                    .foregroundStyle(theme.colors.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(isHighlighted ? theme.colors.hoverStrong : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isHighlighted ? theme.colors.foreground.opacity(0.18) : theme.colors.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.colors.foreground.opacity(isHovered ? 0.035 : 0))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(SottoHomeSuggestionButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

private struct SottoHomeSuggestionButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private struct SottoRecordButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.42)
            .animation(
                reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.14),
                value: configuration.isPressed
            )
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
    let accept: (() -> Void)?
    let retry: (() -> Void)?
    let dismiss: () -> Void

    init(
        message: String,
        accept: (() -> Void)? = nil,
        retry: (() -> Void)? = nil,
        dismiss: @escaping () -> Void
    ) {
        self.message = message
        self.accept = accept
        self.retry = retry
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            SottoIcon("exclamationmark.triangle", size: 14)
                .foregroundStyle(theme.colors.destructiveForeground)
            Text(message)
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.foreground)
            Spacer()
            if let accept {
                Button(SottoLocalization.string("common.use_full_text"), action: accept)
                    .buttonStyle(.sotto(.secondary, size: .small))
            }
            if let retry {
                Button(SottoLocalization.string("common.retry"), action: retry)
                    .buttonStyle(.sotto(.ghost, size: .small))
            }
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
