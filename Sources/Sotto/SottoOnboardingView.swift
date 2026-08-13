import SottoCore
import SottoDesignSystem
import SwiftUI

enum SottoOnboardingStep: Int, CaseIterable, Identifiable, Equatable, Hashable {
    case welcome
    case engine
    case permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Tu voz, en cualquier app."
        case .engine: "Prepara el motor de voz"
        case .permissions: "Dale a Sotto lo necesario"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            "Pulsa un atajo, habla y sigue trabajando. Sotto se ocupa del resto."
        case .engine:
            "Sotto usa Parakeet para convertir tus dictados en texto. Comprueba si ya está disponible o descárgalo ahora."
        case .permissions:
            "El micrófono es necesario para dictar. Accesibilidad permite insertar el texto directamente en la app activa."
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
            Text("Preparando Sotto")
                .font(theme.typography.sectionTitle)
                .foregroundStyle(theme.colors.foreground)
            SottoActivityLabel("Comprobando la instalación…")
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

            Text("Habla.\nSotto escribe.")
                .font(.custom("Inter", size: 30).weight(.semibold))
                .tracking(-0.7)
                .foregroundStyle(theme.colors.foreground)

            Text("Dicta en cualquier aplicación de tu Mac.")
                .font(theme.typography.body)
                .tracking(theme.typography.tracking)
                .foregroundStyle(theme.colors.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, theme.spacing.sm)

            Spacer()

            HStack(spacing: theme.spacing.sm) {
                SottoShortcutKeyView(label: model.preferences.shortcut.displayName)
                Text("Atajo para dictar")
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

            Button("Omitir") {
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
                title: "Pulsa el atajo",
                description: "Usa \(model.preferences.shortcut.displayName) para empezar."
            )
            SottoDivider()
            SottoOnboardingFeatureRow(
                systemImage: "waveform",
                title: "Habla con naturalidad",
                description: "Sotto limpia el texto y corrige tus términos habituales."
            )
            SottoDivider()
            SottoOnboardingFeatureRow(
                systemImage: "arrow.uturn.backward",
                title: "Sigue trabajando",
                description: "El texto vuelve a la aplicación que estabas usando."
            )
        }
    }

    private var engineContent: some View {
        SottoCard(style: .raised, padding: 20) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack(spacing: theme.spacing.md) {
                    SottoOnboardingProcessVisual(state: model.modelState)

                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Parakeet")
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
                title: "Micrófono",
                description: "Necesario para escuchar tu voz.",
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
                title: "Accesibilidad",
                description: "Permite insertar el texto directamente en la app activa.",
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
                    Button("Atrás") {
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
        .accessibilityLabel("Paso \(step.rawValue + 1) de \(SottoOnboardingStep.allCases.count)")
    }

    private var primaryActionTitle: String {
        switch step {
        case .welcome: "Configurar Sotto"
        case .engine:
            switch model.modelState {
            case .notInstalled: "Descargar Parakeet"
            case .failed: "Reintentar descarga"
            case .ready: "Continuar"
            default: "Preparando…"
            }
        case .permissions:
            model.microphonePermission.isGranted ? "Empezar a dictar" : "Terminar por ahora"
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
        case .checking: "Estamos buscando Parakeet en este Mac."
        case .notInstalled: "No hemos encontrado Parakeet. Descárgalo para poder continuar."
        case .installed: "Hemos encontrado los archivos de Parakeet y vamos a comprobarlos."
        case .downloading: "Descargando Parakeet y preparando sus archivos."
        case .validating: "La descarga ha terminado. Estamos verificando Parakeet."
        case .loading: "Parakeet está descargado. Estamos cargando el motor."
        case .ready: "Parakeet está verificado y listo para convertir voz en texto."
        case .failed: "No hemos podido verificar Parakeet. Puedes volver a intentarlo."
        }
    }

    private var engineProgressDescription: String {
        switch model.modelState {
        case .checking: "Buscando el motor…"
        case .installed: "Comprobando los archivos encontrados…"
        case .validating: "Verificando la descarga…"
        case .loading: "Cargando el motor…"
        default: "Preparando…"
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
        case .checking: "Comprobando"
        case .notInstalled: "No detectado"
        case .installed, .downloading, .validating, .loading, .ready: "Detectado"
        case .failed: "No verificado"
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
        case .notDetermined: required ? "Permitir" : "Configurar"
        case .granted: nil
        case .denied, .restricted: "Abrir ajustes"
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
        if status.isGranted { return "Listo" }
        if isRequired { return "Necesario" }
        return "Opcional"
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
