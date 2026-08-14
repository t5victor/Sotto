import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoHomeView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    @State private var isCreatingProject = false
    @State private var projectDraftName = ""
    @State private var projectDraftIcon = "folder"
    @State private var projectDraftAccent: SottoAccent = .blue
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
        .sheet(isPresented: $isCreatingProject, onDismiss: resetProjectDraft) {
            SottoProjectCreationSheet(
                name: $projectDraftName,
                icon: $projectDraftIcon,
                accent: $projectDraftAccent,
                onCancel: {
                    isCreatingProject = false
                },
                onCreate: createProject
            )
            .sottoTheme(theme)
            .frame(width: 520, height: 360)
            .fixedSize()
            .modifier(SottoHomeFittedSheetSizing())
        }
        .onChange(of: model.projects) { _, projects in
            guard let captureProjectID = model.captureProjectID,
                  !projects.contains(where: { $0.id == captureProjectID })
            else { return }
            model.setCaptureProject(nil)
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
                SottoErrorBanner(message: message) {
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
        GeometryReader { proxy in
            SottoHomeComposerLayout(
                composerWidth: metrics.composerWidth,
                selectorWidth: metrics.projectSelectorWidth,
                selectorInset: metrics.projectSelectorInset,
                selectorHeight: metrics.projectSelectorHeight,
                composerHeight: metrics.composerHeight,
                overlap: metrics.composerOverlap
            ) {
                projectSelector(metrics: metrics)
                composer(metrics: metrics)
            }
            .frame(width: proxy.size.width, height: metrics.composerStackHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.composerStackHeight)
    }

    private func projectSelector(metrics: SottoHomeLayoutMetrics) -> some View {
        projectMenu
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.colors.raisedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var projectMenu: some View {
        Menu {
            Button {
                model.setCaptureProject(nil)
            } label: {
                HStack {
                    SottoIcon("tray", size: 14)
                    Text(SottoLocalization.string("home.composer.no_project"))
                    if model.captureProjectID == nil {
                        Spacer(minLength: theme.spacing.lg)
                        SottoIcon("checkmark", size: 12, weight: .semibold)
                    }
                }
            }

            if !model.projects.isEmpty {
                Divider()

                ForEach(model.projects) { project in
                    Button {
                        model.setCaptureProject(project.id)
                    } label: {
                        HStack {
                            SottoIcon(project.icon, size: 14)
                                .foregroundStyle(project.accent.themePalette.background.color)
                            Text(project.name)
                            if model.captureProjectID == project.id {
                                Spacer(minLength: theme.spacing.lg)
                                SottoIcon("checkmark", size: 12, weight: .semibold)
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                beginProjectCreation()
            } label: {
                Label(
                    SottoLocalization.string("home.composer.create_project"),
                    systemImage: "plus"
                )
            }
        } label: {
            HStack(spacing: theme.spacing.sm) {
                SottoIcon("folder", size: 18, weight: .regular)
                Text(selectedProject?.name ?? SottoLocalization.string("home.composer.add_to_project"))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.xs)
            .font(.system(size: 13, weight: .medium))
            .tracking(-0.18)
            .foregroundStyle(selectedProject == nil ? theme.colors.mutedForeground : theme.colors.foreground.opacity(0.82))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .tint(theme.colors.mutedForeground)
        .disabled(model.isBusy)
        .help(SottoLocalization.string("home.composer.add_to_project"))
        .accessibilityLabel(SottoLocalization.string("home.composer.add_to_project"))
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

    private var selectedProject: SottoProject? {
        guard let captureProjectID = model.captureProjectID else { return nil }
        return model.projects.first(where: { $0.id == captureProjectID })
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

    private func beginProjectCreation() {
        projectDraftName = ""
        projectDraftIcon = "folder"
        projectDraftAccent = .blue
        isCreatingProject = true
    }

    private func createProject(name: String, icon: String, accent: SottoAccent) {
        if let project = model.createProject(name: name, icon: icon, accent: accent) {
            model.setCaptureProject(project.id)
        }
        isCreatingProject = false
    }

    private func resetProjectDraft() {
        projectDraftName = ""
        projectDraftIcon = "folder"
        projectDraftAccent = .blue
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

    /// The composer uses the same centered track as the hero, but owns its
    /// internal grid so the selector cannot drift independently from the
    /// recording field.
    var composerWidth: CGFloat {
        contentWidth
    }

    var projectSelectorInset: CGFloat {
        min(max(composerWidth * 0.016, 12), 16)
    }

    var projectSelectorWidth: CGFloat {
        composerWidth - (projectSelectorInset * 2)
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

    var projectSelectorHeight: CGFloat {
        min(max(size.height * 0.038, 40), 48)
    }

    var composerHeight: CGFloat {
        min(max(size.height * 0.080, 106), 124)
    }

    var bottomInset: CGFloat {
        min(max(size.height * 0.018, 24), 36)
    }

    var composerReserve: CGFloat {
        composerStackHeight + bottomInset
    }

    var composerStackHeight: CGFloat {
        projectSelectorHeight + composerHeight - composerOverlap
    }

    var composerOverlap: CGFloat {
        min(max(projectSelectorHeight * 0.35, 12), 16)
    }
}

private struct SottoHomeComposerLayout: Layout {
    let composerWidth: CGFloat
    let selectorWidth: CGFloat
    let selectorInset: CGFloat
    let selectorHeight: CGFloat
    let composerHeight: CGFloat
    let overlap: CGFloat

    private var stackHeight: CGFloat {
        selectorHeight + composerHeight - overlap
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? composerWidth
        return CGSize(width: width, height: stackHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count >= 2 else { return }

        let availableWidth = max(bounds.width, 0)
        let placedComposerWidth = min(composerWidth, availableWidth)
        let placedSelectorWidth = min(
            selectorWidth,
            max(placedComposerWidth - (selectorInset * 2), 0)
        )
        let centerX = bounds.midX
        let composerCenterY = bounds.maxY - (composerHeight / 2)
        let selectorBottom = bounds.maxY - composerHeight + overlap
        let selectorCenterY = selectorBottom - (selectorHeight / 2)

        subviews[0].place(
            at: CGPoint(x: centerX, y: selectorCenterY),
            anchor: .center,
            proposal: ProposedViewSize(width: placedSelectorWidth, height: selectorHeight)
        )
        subviews[1].place(
            at: CGPoint(x: centerX, y: composerCenterY),
            anchor: .center,
            proposal: ProposedViewSize(width: placedComposerWidth, height: composerHeight)
        )
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

private struct SottoHomeFittedSheetSizing: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.presentationSizing(.fitted)
        } else {
            content
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
