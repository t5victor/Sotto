import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

enum SottoOnboardingStep: Int, CaseIterable, Identifiable, Equatable, Hashable {
    case welcome
    case engine
    case permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: SottoLocalization.string("onboarding.step.welcome.title")
        case .engine: SottoLocalization.string("onboarding.step.engine.title")
        case .permissions: SottoLocalization.string("onboarding.step.permissions.title")
        }
    }

    var description: String {
        switch self {
        case .welcome: SottoLocalization.string("onboarding.step.welcome.description")
        case .engine: SottoLocalization.string("onboarding.step.engine.description")
        case .permissions: SottoLocalization.string("onboarding.step.permissions.description")
        }
    }
}

struct SottoAppContentView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        Group {
            if !model.isBootstrapped {
                SottoStartupView()
            } else if model.shouldShowOnboarding {
                SottoOnboardingView(model: model)
            } else {
                SottoRootView(model: model)
            }
        }
        .background(theme.colors.surface)
    }
}

private struct SottoStartupView: View {
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            SottoIcon("waveform", size: 22, weight: .medium)
                .foregroundStyle(theme.colors.accentInk)
            Text(SottoLocalization.string("onboarding.startup_title"))
                .font(theme.typography.sectionTitle)
                .foregroundStyle(theme.colors.foreground)
            SottoActivityLabel(SottoLocalization.string("onboarding.startup_activity"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.surface)
    }
}

struct SottoOnboardingView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: SottoOnboardingStep

    init(model: SottoAppModel, initialStep: SottoOnboardingStep = .welcome) {
        self.model = model
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        HStack(spacing: 0) {
            aside
                .frame(width: 300)
                .background(theme.colors.canvas)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(width: 1)
                }

            VStack(alignment: .leading, spacing: 0) {
                topBar

                Spacer(minLength: theme.spacing.xxl)

                SottoReveal {
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)

                Spacer(minLength: theme.spacing.xxl)

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 52)
            .padding(.vertical, theme.spacing.xxl)
            .background(theme.colors.surface)
        }
        .animation(
            reduceMotion
                ? nil
                : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular),
            value: step
        )
    }

    private var aside: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            SottoOnboardingMark()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, theme.spacing.xl)

            Text(SottoLocalization.string("onboarding.aside.title"))
                .font(.custom("Inter", size: 30).weight(.semibold))
                .tracking(-0.7)
                .foregroundStyle(theme.colors.foreground)

            Text(SottoLocalization.string("onboarding.aside.description"))
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, theme.spacing.sm)

            Spacer()

            HStack(spacing: theme.spacing.sm) {
                SottoShortcutKeyView(label: model.preferences.shortcut.localizedDisplayName)
                Text(SottoLocalization.string("onboarding.aside.shortcut"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.mutedForeground)
            }
        }
        .padding(.horizontal, theme.spacing.xxl)
        .padding(.vertical, theme.spacing.xxl)
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button(SottoLocalization.string("onboarding.skip")) {
                model.completeOnboarding()
            }
            .buttonStyle(.sotto(.ghost, size: .small))
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text(step.title)
                    .font(theme.typography.pageTitle)
                    .tracking(-0.42)
                    .foregroundStyle(theme.colors.foreground)
                Text(step.description)
                    .font(theme.typography.body)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch step {
            case .welcome:
                welcomeContent
            case .engine:
                engineContent
            case .permissions:
                permissionsContent
            }
        }
        .id(step)
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SottoOnboardingFeatureRow(
                systemImage: "keyboard",
                title: SottoLocalization.string("onboarding.feature.shortcut.title"),
                description: SottoLocalization.format(
                    "onboarding.feature.shortcut.description",
                    model.preferences.shortcut.localizedDisplayName
                )
            )
            SottoDivider()
            SottoOnboardingFeatureRow(
                systemImage: "waveform",
                title: SottoLocalization.string("onboarding.feature.natural.title"),
                description: SottoLocalization.string("onboarding.feature.natural.description")
            )
            SottoDivider()
            SottoOnboardingFeatureRow(
                systemImage: "arrow.uturn.backward",
                title: SottoLocalization.string("onboarding.feature.continue.title"),
                description: SottoLocalization.string("onboarding.feature.continue.description")
            )
        }
    }

    private var engineContent: some View {
        SottoCard(style: .raised, padding: 20) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack(spacing: theme.spacing.md) {
                    SottoOnboardingProcessVisual(state: model.modelState)

                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text(SottoLocalization.string("onboarding.engine.name"))
                            .font(theme.typography.sectionTitle)
                            .foregroundStyle(theme.colors.foreground)
                        HStack(spacing: theme.spacing.xs) {
                            Circle()
                                .fill(engineDetectionColor)
                                .frame(width: 6, height: 6)
                            Text(engineDetectionLabel)
                                .font(theme.typography.caption)
                                .foregroundStyle(engineDetectionColor)
                        }
                    }
                    Spacer()
                    engineStatusIcon
                }

                Text(engineStatusDescription)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if case .downloading(let progress, let detail) = model.modelState {
                    SottoDivider()
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        HStack {
                            Text(detail)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.mutedForeground)
                            Spacer()
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(theme.typography.caption.monospacedDigit())
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(theme.colors.accent)
                    }
                } else if showsIndeterminateProgress {
                    SottoDivider()
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        HStack {
                            Text(engineProgressDescription)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.mutedForeground)
                            Spacer()
                        }
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(theme.colors.accent)
                    }
                }

                if case .failed(let message) = model.modelState {
                    SottoDivider()
                    Text(message)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.destructiveForeground)
                }
            }
        }
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SottoOnboardingPermissionRow(
                title: SottoLocalization.string("onboarding.permission.microphone.title"),
                description: SottoLocalization.string("onboarding.permission.microphone.description"),
                systemImage: "mic",
                status: model.microphonePermission,
                isRequired: true,
                actionTitle: permissionActionTitle(model.microphonePermission, required: true)
            ) {
                if model.microphonePermission == .notDetermined {
                    model.requestMicrophonePermission()
                } else {
                    model.openMicrophoneSettings()
                }
            }

            SottoDivider()

            SottoOnboardingPermissionRow(
                title: SottoLocalization.string("onboarding.permission.accessibility.title"),
                description: SottoLocalization.string("onboarding.permission.accessibility.description"),
                systemImage: "accessibility",
                status: model.accessibilityPermission,
                isRequired: false,
                actionTitle: permissionActionTitle(model.accessibilityPermission, required: false)
            ) {
                if model.accessibilityPermission == .granted {
                    model.openAccessibilitySettings()
                } else {
                    model.requestAccessibilityPermission()
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(spacing: theme.spacing.xs) {
                ForEach(SottoOnboardingStep.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? theme.colors.accent : theme.colors.border)
                        .frame(width: item == step ? 28 : 8, height: 4)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: theme.motion.fast),
                            value: step
                        )
                }
            }

            HStack(spacing: theme.spacing.md) {
                if step != .welcome {
                    Button(SottoLocalization.string("common.back")) {
                        move(to: SottoOnboardingStep(rawValue: step.rawValue - 1) ?? .welcome)
                    }
                    .buttonStyle(.sotto(.ghost, size: .small))
                }

                Spacer()

                Button(primaryActionTitle) {
                    primaryAction()
                }
                .buttonStyle(.sotto(.primary, size: .regular))
                .disabled(primaryActionDisabled)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            SottoLocalization.format(
                "onboarding.step_indicator",
                Int64(step.rawValue + 1),
                Int64(SottoOnboardingStep.allCases.count)
            )
        )
    }

    private var primaryActionTitle: String {
        switch step {
        case .welcome: SottoLocalization.string("onboarding.action.configure")
        case .engine:
            switch model.modelState {
            case .notInstalled: SottoLocalization.string("common.download")
            case .failed: SottoLocalization.string("common.retry_download")
            case .ready: SottoLocalization.string("onboarding.action.continue")
            default: SottoLocalization.string("onboarding.engine.progress.preparing")
            }
        case .permissions:
            model.microphonePermission.isGranted
                ? SottoLocalization.string("onboarding.action.start")
                : SottoLocalization.string("onboarding.action.finish_later")
        }
    }

    private var primaryActionDisabled: Bool {
        guard step == .engine else { return false }
        return switch model.modelState {
        case .notInstalled, .failed, .ready: false
        default: true
        }
    }

    private func primaryAction() {
        switch step {
        case .welcome:
            move(to: .engine)
        case .engine:
            switch model.modelState {
            case .notInstalled:
                model.installModel()
            case .failed:
                model.reinstallModel()
            case .ready:
                move(to: .permissions)
            default:
                break
            }
        case .permissions:
            model.completeOnboarding()
        }
    }

    private func move(to nextStep: SottoOnboardingStep) {
        withAnimation(
            reduceMotion
                ? nil
                : .timingCurve(0.23, 1, 0.32, 1, duration: theme.motion.regular)
        ) {
            step = nextStep
        }
    }

    private var engineStatusDescription: String {
        switch model.modelState {
        case .checking: SottoLocalization.string("onboarding.engine.status.checking")
        case .notInstalled: SottoLocalization.string("onboarding.engine.status.not_installed")
        case .installed: SottoLocalization.string("onboarding.engine.status.installed")
        case .downloading: SottoLocalization.string("onboarding.engine.status.downloading")
        case .validating: SottoLocalization.string("onboarding.engine.status.validating")
        case .loading: SottoLocalization.string("onboarding.engine.status.loading")
        case .ready: SottoLocalization.string("onboarding.engine.status.ready")
        case .failed: SottoLocalization.string("onboarding.engine.status.failed")
        }
    }

    private var engineProgressDescription: String {
        switch model.modelState {
        case .checking: SottoLocalization.string("onboarding.engine.progress.checking")
        case .installed: SottoLocalization.string("onboarding.engine.progress.installed")
        case .validating: SottoLocalization.string("onboarding.engine.progress.validating")
        case .loading: SottoLocalization.string("onboarding.engine.progress.loading")
        default: SottoLocalization.string("onboarding.engine.progress.preparing")
        }
    }

    private var showsIndeterminateProgress: Bool {
        switch model.modelState {
        case .checking, .installed, .validating, .loading: true
        default: false
        }
    }

    private var engineDetectionLabel: String {
        switch model.modelState {
        case .checking: SottoLocalization.string("onboarding.engine.detection.checking")
        case .notInstalled: SottoLocalization.string("onboarding.engine.detection.not_detected")
        case .installed, .downloading, .validating, .loading, .ready:
            SottoLocalization.string("onboarding.engine.detection.detected")
        case .failed: SottoLocalization.string("onboarding.engine.detection.not_verified")
        }
    }

    private var engineDetectionColor: Color {
        switch model.modelState {
        case .ready: theme.colors.successForeground
        case .notInstalled: theme.colors.warningForeground
        case .failed: theme.colors.destructiveForeground
        case .checking, .installed, .downloading, .validating, .loading: theme.colors.warningForeground
        }
    }

    @ViewBuilder
    private var engineStatusIcon: some View {
        switch model.modelState {
        case .ready:
            SottoIcon("checkmark.circle.fill", size: 18)
                .foregroundStyle(theme.colors.successForeground)
        case .notInstalled:
            SottoIcon("arrow.down.circle", size: 18)
                .foregroundStyle(theme.colors.accentInk)
        case .failed:
            SottoIcon("exclamationmark.circle.fill", size: 18)
                .foregroundStyle(theme.colors.destructiveForeground)
        default:
            SottoPixelLoader(color: theme.colors.accent)
        }
    }

    private func permissionActionTitle(
        _ status: SottoPermissionStatus,
        required: Bool
    ) -> String? {
        switch status {
        case .notDetermined:
            required
                ? SottoLocalization.string("common.allow")
                : SottoLocalization.string("common.configure")
        case .granted: nil
        case .denied, .restricted: SottoLocalization.string("common.open_settings")
        }
    }
}

private struct SottoOnboardingProcessVisual: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: SottoModelState

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: reduceMotion || !isAnimated)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 6) % 16

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(5), spacing: 3), count: 4),
                spacing: 3
            ) {
                ForEach(0..<16, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(pixelColor)
                        .frame(width: 5, height: 5)
                        .opacity(pixelOpacity(index: index, phase: phase))
                }
            }
            .frame(width: 41, height: 41)
        }
        .frame(width: 52, height: 52)
        .background(theme.colors.field)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous)
                .strokeBorder(theme.colors.border)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
        .accessibilityHidden(true)
    }

    private var isAnimated: Bool {
        switch state {
        case .checking, .installed, .downloading, .validating, .loading: true
        default: false
        }
    }

    private var pixelColor: Color {
        switch state {
        case .ready: theme.colors.success
        case .failed: theme.colors.destructive
        case .notInstalled: theme.colors.subtleForeground
        default: theme.colors.accent
        }
    }

    private func pixelOpacity(index: Int, phase: Int) -> Double {
        if state.isReady {
            return [0.32, 0.55, 0.9, 0.45, 0.72, 0.38, 0.82, 0.52, 0.25, 0.62, 1.0, 0.42, 0.5, 0.76, 0.34, 0.58][index]
        }
        if case .failed = state { return index.isMultiple(of: 3) ? 0.9 : 0.25 }
        if case .notInstalled = state { return index.isMultiple(of: 5) ? 0.55 : 0.18 }
        let distance = (index - phase + 16) % 16
        return switch distance {
        case 0: 1
        case 1, 15: 0.62
        case 2, 14: 0.34
        default: 0.14
        }
    }
}

private struct SottoOnboardingMark: View {
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(Array([0.32, 0.62, 1.0, 0.48, 0.78, 0.38, 0.92, 0.58].enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(theme.colors.accent)
                    .frame(width: 4, height: 54 * height)
            }
        }
        .frame(height: 54, alignment: .center)
        .accessibilityHidden(true)
    }
}

private struct SottoShortcutKeyView: View {
    @Environment(\.sottoTheme) private var theme
    let label: String

    var body: some View {
        Text(label)
            .font(theme.typography.mono)
            .foregroundStyle(theme.colors.foreground)
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 27)
            .background(theme.colors.field)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                    .strokeBorder(theme.colors.border)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
    }
}

private struct SottoOnboardingFeatureRow: View {
    @Environment(\.sottoTheme) private var theme
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            SottoIcon(systemImage, size: 15)
                .foregroundStyle(theme.colors.accentInk)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.foreground)
                Text(description)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, theme.spacing.md)
    }
}

private struct SottoOnboardingPermissionRow: View {
    @Environment(\.sottoTheme) private var theme
    let title: String
    let description: String
    let systemImage: String
    let status: SottoPermissionStatus
    let isRequired: Bool
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            SottoIcon(systemImage, size: 14)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.foreground)
                Text(description)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.md)

            statusView

            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.sotto(.secondary, size: .small))
            }
        }
        .padding(.vertical, theme.spacing.md)
    }

    private var statusLabel: String {
        if status.isGranted { return SottoLocalization.string("onboarding.permission.ready") }
        if isRequired { return SottoLocalization.string("onboarding.permission.required") }
        return SottoLocalization.string("onboarding.permission.optional")
    }

    private var statusIcon: String {
        status.isGranted ? "checkmark" : (isRequired ? "exclamationmark" : "minus")
    }

    private var statusColor: Color {
        if status.isGranted { return theme.colors.successForeground }
        return isRequired ? theme.colors.warningForeground : theme.colors.subtleForeground
    }

    private var statusView: some View {
        HStack(spacing: theme.spacing.xs) {
            SottoIcon(statusIcon, size: 11)
                .foregroundStyle(statusColor)
            Text(statusLabel)
                .font(theme.typography.caption)
                .foregroundStyle(statusColor)
        }
    }
}
