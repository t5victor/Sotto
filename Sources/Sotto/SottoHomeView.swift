import SottoCore
import SottoDesignSystem
import SwiftUI

struct SottoHomeView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                SottoPageHeader(
                    title: "Habla. Sotto escribe.",
                    description: "Dictado rápido y privado en cualquier aplicación de tu Mac."
                )

                if case .failed(let message) = model.dictationState {
                    SottoErrorBanner(message: message) {
                        model.dismissFailure()
                    }
                }

                dictationCard

                HStack(alignment: .top, spacing: theme.spacing.lg) {
                    modelCard
                    behaviorCard
                }

                if let first = model.history.first {
                    recentCard(first)
                }
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
    }

    private var dictationCard: some View {
        SottoCard(style: .raised, padding: theme.spacing.xl) {
            HStack(alignment: .center, spacing: theme.spacing.xl) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoBadge(
                        statusLabel,
                        systemImage: statusIcon,
                        tone: statusTone
                    )

                    Text(dictationTitle)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.foreground)

                    Text(dictationDescription)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: theme.spacing.sm) {
                        Button(primaryActionTitle) {
                            if model.modelState.isInstalled {
                                model.toggleDictation()
                            } else {
                                model.installModel()
                            }
                        }
                        .buttonStyle(.sotto(model.isListening ? .secondary : .primary))
                        .disabled(primaryActionDisabled)

                        SottoBadge(model.preferences.shortcut.displayName, tone: .neutral)
                    }
                }

                Spacer(minLength: theme.spacing.xl)

                SottoRecordingPill(
                    state: recordingVisualState,
                    level: model.audioLevel
                )
            }
        }
    }

    private var modelCard: some View {
        SottoCard {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                SottoSectionHeader(
                    "Motor de voz",
                    description: "El reconocimiento ocurre en este Mac."
                )
                Divider()
                HStack(spacing: theme.spacing.md) {
                    Image(systemName: "cpu.fill")
                        .foregroundStyle(theme.colors.accent)
                        .frame(width: 34, height: 34)
                        .background(theme.colors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.small))

                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Parakeet TDT 0.6B v3")
                            .font(theme.typography.label)
                        Text(model.modelSizeDescription.map { "25 idiomas · \($0)" } ?? "25 idiomas · Apple Silicon")
                            .font(theme.typography.body)
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
                Divider()
                SottoToggleRow(
                    "Normalizar texto",
                    description: "Limpia espacios y puntuación.",
                    systemImage: "textformat",
                    isOn: $model.preferences.normalizeText
                )
                Divider()
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
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.sotto(.ghost, size: .small))
                    .help("Copiar")
                }
                Text(record.text)
                    .font(theme.typography.body)
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
        if model.modelState.isReady { return "Empezar a dictar" }
        if case .downloading = model.modelState { return "Descargando…" }
        if case .loading = model.modelState { return "Cargando…" }
        if case .validating = model.modelState { return "Validando…" }
        return "Descargar Parakeet"
    }

    private var primaryActionDisabled: Bool {
        if model.isListening { return false }
        return switch model.modelState {
        case .notInstalled, .failed: false
        case .ready: false
        default: true
        }
    }
}

