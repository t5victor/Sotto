import SottoCore
import SottoDesignSystem
import SwiftUI

struct SottoHomeView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SottoReveal {
                    SottoPageHeader(
                        title: "Habla. Sotto escribe.",
                        description: "Dictado rápido y privado en cualquier aplicación de tu Mac."
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
                    HStack(alignment: .top, spacing: theme.spacing.lg) {
                        modelCard
                        behaviorCard
                    }
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
        .background(theme.colors.canvas)
    }

    private var dictationCard: some View {
        SottoCard(style: .raised, padding: 20) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoBadge(
                        statusLabel,
                        systemImage: statusIcon,
                        tone: statusTone
                    )

                    Text(dictationTitle)
                        .font(.custom("Inter", size: 18).weight(.semibold))
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

                        SottoShortcutKey(model.preferences.shortcut.displayName)
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
            SottoActivityLabel("Preparando")
        case .transcribing:
            SottoActivityLabel("Transcribiendo")
        case .inserting:
            SottoActivityLabel("Insertando")
        default:
            SottoRecordingPill(
                state: recordingVisualState,
                level: model.audioLevel
            )
        }
    }

    private var modelCard: some View {
        SottoCard {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                SottoSectionHeader(
                    "Motor de voz",
                    description: "El reconocimiento ocurre en este Mac."
                )
                SottoDivider()
                HStack(spacing: theme.spacing.md) {
                    SottoIcon("cpu", size: 15)
                        .foregroundStyle(theme.colors.accentInk)
                        .frame(width: 30, height: 30)
                        .background(theme.colors.accentTint)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.small))

                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Parakeet TDT 0.6B v3")
                            .font(theme.typography.label)
                            .tracking(theme.typography.tracking)
                        Text(model.modelSizeDescription.map { "25 idiomas · \($0)" } ?? "25 idiomas · Apple Silicon")
                            .font(theme.typography.caption)
                            .tracking(theme.typography.tracking)
                            .foregroundStyle(theme.colors.mutedForeground)
                    }
                    Spacer()
                    SottoBadge(model.modelState.title, tone: model.modelState.tone)
                }
            }
        }
    }

    private var behaviorCard: some View {
        SottoCard {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                SottoSectionHeader(
                    "Comportamiento",
                    description: "Ajustes aplicados a cada dictado."
                )
                SottoDivider()
                SottoToggleRow(
                    "Normalizar texto",
                    description: "Limpia espacios y puntuación.",
                    systemImage: "textformat",
                    isOn: $model.preferences.normalizeText
                )
                SottoDivider()
                SottoToggleRow(
                    "Eliminar muletillas",
                    description: "Quita sonidos como «eh» o «mmm».",
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
                    SottoSectionHeader("Último dictado")
                    Spacer()
                    SottoBadge(record.insertionOutcome.displayName, tone: .success)
                    Button {
                        model.copyToPasteboard(record.text)
                    } label: {
                        SottoIcon("doc.on.doc", size: 13)
                    }
                    .buttonStyle(.sotto(.ghost, size: .small))
                    .help("Copiar")
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

    private var statusLabel: String {
        switch model.dictationState {
        case .idle: model.modelState.isReady ? "Preparado" : model.modelState.title
        case .preparing: "Preparando"
        case .listening: "Micrófono activo"
        case .transcribing: "Transcribiendo"
        case .inserting: "Insertando"
        case .completed(_, let outcome): outcome.displayName
        case .failed: "Error"
        }
    }

    private var statusIcon: String {
        switch model.dictationState {
        case .listening: "mic.fill"
        case .transcribing: "waveform.badge.magnifyingglass"
        case .failed: "exclamationmark.triangle.fill"
        default: "checkmark.circle.fill"
        }
    }

    private var statusTone: SottoBadgeTone {
        switch model.dictationState {
        case .failed: .destructive
        case .listening, .transcribing, .inserting: .accent
        default: model.modelState.isReady ? .success : model.modelState.tone
        }
    }

    private var dictationTitle: String {
        switch model.dictationState {
        case .idle: model.modelState.isReady ? "Listo para dictar" : "Prepara el motor de voz"
        case .preparing: "Preparando el micrófono"
        case .listening: "Te estoy escuchando"
        case .transcribing: "Convirtiendo voz en texto"
        case .inserting: "Enviando el texto"
        case .completed: "Dictado completado"
        case .failed: "El dictado necesita atención"
        }
    }

    private var dictationDescription: String {
        if model.modelState.isReady {
            return model.preferences.holdToTalk
                ? "Mantén pulsado \(model.preferences.shortcut.displayName), habla y suelta para insertar el texto."
                : "Pulsa \(model.preferences.shortcut.displayName) para iniciar y vuelve a pulsarlo para terminar."
        }
        return model.modelState.detail
    }

    private var recordingVisualState: SottoRecordingState {
        switch model.dictationState {
        case .listening: .listening
        case .transcribing, .inserting: .transcribing
        default: .idle
        }
    }

    private var primaryActionTitle: String {
        if model.isListening { return "Detener" }
        if model.dictationState.canCancel { return "Cancelar" }
        if model.modelState.isReady { return "Empezar a dictar" }
        if case .downloading = model.modelState { return "Descargando…" }
        if case .loading = model.modelState { return "Cargando…" }
        if case .validating = model.modelState { return "Validando…" }
        if case .failed = model.modelState { return "Reinstalar Parakeet" }
        return "Descargar Parakeet"
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
            Button("Cerrar", action: dismiss)
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
            Button("Cerrar", action: dismiss)
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
                    .strokeBorder(theme.colors.strongBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 1, y: 1)
    }
}
