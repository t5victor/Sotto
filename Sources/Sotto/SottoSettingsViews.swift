import SottoCore
import SottoDesignSystem
import SwiftUI

struct SottoModelsView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var confirmsModelDeletion = false
    @State private var confirmsModelRepair = false

    var body: some View {
        SottoSettingsPage(
            title: "Modelo de voz",
            description: "Sotto usa una única instalación local y verificable de Parakeet."
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("waveform.badge.mic", size: 17)
                            .foregroundStyle(theme.colors.accentInk)
                            .frame(width: 38, height: 38)
                            .background(theme.colors.accentTint)
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.radii.medium)
                                    .strokeBorder(theme.colors.accent.opacity(0.24))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium))

                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            HStack {
                                Text("Parakeet TDT 0.6B v3")
                                    .font(theme.typography.sectionTitle)
                                SottoBadge(model.modelState.title, tone: model.modelState.tone)
                            }
                            Text("Reconocimiento multilingüe Core ML optimizado para Apple Silicon.")
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
                            Text("Idioma del dictado")
                                .font(theme.typography.label)
                            Text("Automático funciona bien; fijarlo ayuda a evitar alfabetos incorrectos.")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker("Idioma", selection: $model.preferences.language) {
                            ForEach(SottoLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 205)
                    }

                    SottoDivider()

                    LabeledContent("Idiomas", value: "25 idiomas europeos")
                    LabeledContent("Ejecución", value: "Core ML · Neural Engine")
                    LabeledContent("Licencia del modelo", value: "CC BY 4.0")
                    if let size = model.modelSizeDescription {
                        LabeledContent("Espacio utilizado", value: size)
                    }

                    Text("El audio no se envía a ningún servidor. La conexión sólo se utiliza para descargar el modelo desde FluidInference en Hugging Face.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar Parakeet de este Mac?",
            isPresented: $confirmsModelDeletion,
            titleVisibility: .visible
        ) {
            Button("Eliminar modelo", role: .destructive) {
                model.deleteModel()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Podrás volver a descargarlo. Tus ajustes, vocabulario e historial no se borrarán.")
        }
        .confirmationDialog(
            "¿Reinstalar Parakeet?",
            isPresented: $confirmsModelRepair,
            titleVisibility: .visible
        ) {
            Button("Eliminar y volver a descargar", role: .destructive) {
                model.reinstallModel()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Sotto eliminará sólo la caché fija de Parakeet y descargará una copia limpia.")
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
                    Text("La descarga puede ocupar varios cientos de MB.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                }
                Spacer()
                Button("Descargar modelo") {
                    model.installModel()
                }
                .buttonStyle(.sotto())
            }

        case .failed:
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(model.modelState.detail)
                        .font(theme.typography.body)
                    Text("La reparación elimina la copia dañada antes de descargarla de nuevo.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                }
                Spacer()
                Button("Reinstalar modelo") {
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
                Button("Cancelar") {
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
                Button("Eliminar modelo") {
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
            title: "Vocabulario",
            description: "Corrige nombres, marcas y términos después del reconocimiento local."
        ) {
            SottoCard {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader(
                        "Añadir sustitución",
                        description: "Indica lo que Parakeet suele oír y cómo debe escribirse."
                    )
                    HStack(spacing: theme.spacing.sm) {
                        TextField("Forma hablada", text: $spokenForm)
                            .textFieldStyle(.sotto)
                        SottoIcon("arrow.right", size: 13)
                            .foregroundStyle(theme.colors.subtleForeground)
                        TextField("Escribir como", text: $replacement)
                            .textFieldStyle(.sotto)
                        Button("Añadir") {
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
                            systemImage: "text.book.closed",
                            title: "Sin términos todavía",
                            description: "Puedes empezar con nombres propios o palabras técnicas."
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
                                .help("Eliminar término")
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
            title: "Atajos",
            description: "Inicia el dictado sin apartar las manos del teclado."
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("command", size: 15)
                            .foregroundStyle(theme.colors.accentInk)
                            .frame(width: 30, height: 30)
                            .background(theme.colors.accentTint)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small))

                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Atajo global")
                                .font(theme.typography.label)
                            Text("Funciona incluso cuando Sotto no es la aplicación activa.")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker("Atajo", selection: shortcutBinding) {
                            Text("⌥ Espacio").tag(SottoShortcut.defaultDictation)
                            Text("⌃ ⌥ Espacio").tag(
                                SottoShortcut(keyCode: 49, carbonModifiers: 6_144, displayName: "⌃ ⌥ Espacio")
                            )
                            Text("⌃ ⇧ Espacio").tag(
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
                        "Mantener para dictar",
                        description: "Suelta el atajo para detener la grabación.",
                        systemImage: "hand.tap",
                        isOn: $model.preferences.holdToTalk
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Sonidos de estado",
                        description: "Confirma el inicio y el final del dictado.",
                        systemImage: "speaker.wave.2",
                        isOn: $model.preferences.playSounds
                    )
                    SottoDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Duración máxima")
                                .font(theme.typography.label)
                            Text("Sotto detiene y transcribe automáticamente al alcanzar el límite.")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }
                        Spacer()
                        Picker(
                            "Duración máxima",
                            selection: $model.preferences.maximumRecordingDuration
                        ) {
                            Text("2 minutos").tag(TimeInterval(120))
                            Text("5 minutos").tag(TimeInterval(300))
                            Text("10 minutos").tag(TimeInterval(600))
                            Text("30 minutos").tag(TimeInterval(1_800))
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

struct SottoAppearanceView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: "Apariencia",
            description: "Un sistema source-owned inspirado en Beautiful UI."
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader(
                        "Beautiful UI",
                        description: "Inter, negros neutros, hairlines de un píxel y controles compactos."
                    )

                    HStack(spacing: theme.spacing.sm) {
                        ForEach(Array(appearanceSwatches.enumerated()), id: \.offset) { index, swatch in
                            RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                                .fill(swatch)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.radii.small, style: .continuous)
                                        .strokeBorder(theme.colors.strongBorder)
                                }
                                .accessibilityLabel("Muestra de superficie \(index + 1)")
                        }
                    }

                    SottoDivider()

                    HStack(spacing: theme.spacing.sm) {
                        SottoBadge("Preparado", systemImage: "checkmark", tone: .success)
                        SottoActivityLabel("Procesando")
                        Spacer()
                        Button("Secundario") {}
                            .buttonStyle(.sotto(.secondary, size: .small))
                        Button("Acción") {}
                            .buttonStyle(.sotto(.primary, size: .small))
                    }

                    Text("Los tokens siguen viviendo en SottoTheme y pueden reemplazarse sin modificar las pantallas.")
                        .font(theme.typography.caption)
                        .tracking(theme.typography.tracking)
                        .foregroundStyle(theme.colors.mutedForeground)
                }
            }
        }
    }

    private var appearanceSwatches: [Color] {
        [
            theme.colors.canvas,
            theme.colors.mutedSurface,
            theme.colors.surface,
            theme.colors.field,
            theme.colors.hoverStrong,
            theme.colors.accent,
        ]
    }
}

struct SottoPrivacyView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        SottoSettingsPage(
            title: "Privacidad",
            description: "La voz y los textos permanecen en este Mac."
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    SottoPermissionRow(
                        "Micrófono",
                        description: "Necesario para capturar tu voz.",
                        systemImage: "mic",
                        state: model.microphonePermission.designState,
                        actionTitle: model.microphonePermission == .notDetermined ? "Permitir" : permissionAction(model.microphonePermission)
                    ) {
                        if model.microphonePermission == .notDetermined {
                            model.requestMicrophonePermission()
                        } else {
                            model.openMicrophoneSettings()
                        }
                    }
                    SottoDivider()
                    SottoPermissionRow(
                        "Accesibilidad",
                        description: "Permite insertar el texto en la aplicación activa.",
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
                        "Insertar automáticamente",
                        description: "Sin Accesibilidad, el texto se copia al portapapeles.",
                        systemImage: "text.cursor",
                        isOn: $model.preferences.insertAutomatically
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Guardar historial local",
                        description: "Conserva los últimos dictados en Application Support/Sotto.",
                        systemImage: "clock.arrow.circlepath",
                        isOn: $model.preferences.keepHistory
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Abrir al iniciar sesión",
                        description: "Mantiene Sotto disponible en la barra de menús.",
                        systemImage: "power",
                        isOn: launchAtLoginBinding
                    )
                    if let message = model.launchAtLoginMessage {
                        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
                            Text(message)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.warningForeground)
                            Spacer()
                            Button("Abrir ítems de inicio") {
                                model.openLoginItemsSettings()
                            }
                            .buttonStyle(.sotto(.secondary, size: .small))
                        }
                    }
                }
            }
        }
    }

    private func permissionAction(_ status: SottoPermissionStatus) -> String? {
        status == .granted ? "Ajustes" : "Configurar"
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
            title: "Historial",
            description: "Tus dictados guardados localmente en este Mac."
        ) {
            if model.history.isEmpty {
                SottoCard {
                    SottoEmptyState(
                        systemImage: "clock.arrow.circlepath",
                        title: "Aún no hay dictados",
                        description: "Cuando completes uno aparecerá aquí para copiarlo o revisarlo."
                    )
                }
            } else {
                HStack {
                    Text("\(model.history.count) dictados")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                    Spacer()
                    Button("Borrar historial") {
                        confirmsHistoryDeletion = true
                    }
                    .buttonStyle(.sotto(.destructive, size: .small))
                }

                LazyVStack(spacing: theme.spacing.md) {
                    ForEach(model.history) { record in
                        SottoCard {
                            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                                HStack {
                                    Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.mutedForeground)
                                    if let app = record.targetApplication {
                                        SottoBadge(app, tone: .neutral)
                                    }
                                    SottoBadge(record.insertionOutcome.displayName, tone: .success)
                                    Spacer()
                                    Button {
                                        model.copyToPasteboard(record.text)
                                    } label: {
                                        SottoIcon("doc.on.doc", size: 13)
                                    }
                                    .buttonStyle(.sotto(.ghost, size: .small))
                                    Button {
                                        model.removeHistory(id: record.id)
                                    } label: {
                                        SottoIcon("trash", size: 13)
                                    }
                                    .buttonStyle(.sotto(.ghost, size: .small))
                                }
                                Text(record.text)
                                    .font(theme.typography.body)
                                    .foregroundStyle(theme.colors.foreground)
                                    .textSelection(.enabled)
                                Text("\(record.duration.formatted(.number.precision(.fractionLength(1)))) s de audio · \(record.processingTime.formatted(.number.precision(.fractionLength(2)))) s de proceso")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.subtleForeground)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "¿Borrar todo el historial?",
            isPresented: $confirmsHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button("Borrar historial", role: .destructive) {
                model.clearHistory()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción elimina del Mac todos los dictados guardados por Sotto.")
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
                SottoPageHeader(title: title, description: description)
                content
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
        .background(theme.colors.canvas)
    }
}

private struct SottoEmptyState: View {
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
