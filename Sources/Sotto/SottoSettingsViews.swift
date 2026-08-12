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
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(theme.colors.accent)
                            .frame(width: 42, height: 42)
                            .background(theme.colors.accent.opacity(0.1))
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

                    Divider()

                    modelControls

                    Divider()

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

                    Divider()

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
            HStack(spacing: theme.spacing.md) {
                ProgressView()
                    .controlSize(.small)
                Text(model.modelState.detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.mutedForeground)
            }

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
                            .textFieldStyle(.roundedBorder)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(theme.colors.subtleForeground)
                        TextField("Escribir como", text: $replacement)
                            .textFieldStyle(.roundedBorder)
                        Button("Añadir") {
                            model.addVocabulary(spokenForm: spokenForm, replacement: replacement)
                            spokenForm = ""
                            replacement = ""
                        }
                        .buttonStyle(.sotto())
                        .disabled(spokenForm.trimmed.isEmpty || replacement.trimmed.isEmpty)
                    }

                    Divider()

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
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(theme.colors.subtleForeground)
                                Text(entry.replacement)
                                    .font(theme.typography.label)
                                Spacer()
                                Button {
                                    model.removeVocabulary(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.sotto(.ghost, size: .small))
                                .help("Eliminar término")
                            }
                            if entry.id != model.vocabulary.last?.id { Divider() }
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
                        Image(systemName: "command")
                            .foregroundStyle(theme.colors.accent)
                            .frame(width: 32, height: 32)
                            .background(theme.colors.accent.opacity(0.1))
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

                    Divider()

                    SottoToggleRow(
                        "Mantener para dictar",
                        description: "Suelta el atajo para detener la grabación.",
                        systemImage: "hand.tap",
                        isOn: $model.preferences.holdToTalk
                    )
                    Divider()
                    SottoToggleRow(
                        "Sonidos de estado",
                        description: "Confirma el inicio y el final del dictado.",
                        systemImage: "speaker.wave.2",
                        isOn: $model.preferences.playSounds
                    )
                    Divider()
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
            description: "La interfaz completa consume los mismos tokens semánticos."
        ) {
            SottoCard {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    SottoSectionHeader(
                        "Color de énfasis",
                        description: "El cambio se propaga a botones, iconos, etiquetas y overlay."
                    )

                    HStack(spacing: theme.spacing.md) {
                        ForEach(SottoAccent.allCases) { accent in
                            Button {
                                model.preferences.accent = accent
                            } label: {
                                VStack(spacing: theme.spacing.sm) {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if model.accent == accent {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(accent.foregroundColor)
                                            }
                                        }
                                        .overlay {
                                            Circle()
                                                .strokeBorder(
                                                    model.accent == accent ? theme.colors.foreground : .clear,
                                                    lineWidth: 2
                                                )
                                                .padding(-4)
                                        }
                                    Text(accent.displayName)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.mutedForeground)
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(accent.displayName)")
                            .accessibilityAddTraits(model.accent == accent ? .isSelected : [])
                        }
                    }
                }
            }
        }
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
                    Divider()
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
                    Divider()
                    SottoToggleRow(
                        "Insertar automáticamente",
                        description: "Sin Accesibilidad, el texto se copia al portapapeles.",
                        systemImage: "text.cursor",
                        isOn: $model.preferences.insertAutomatically
                    )
                    Divider()
                    SottoToggleRow(
                        "Guardar historial local",
                        description: "Conserva los últimos dictados en Application Support/Sotto.",
                        systemImage: "clock.arrow.circlepath",
                        isOn: $model.preferences.keepHistory
                    )
                    Divider()
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
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.sotto(.ghost, size: .small))
                                    Button {
                                        model.removeHistory(id: record.id)
                                    } label: {
                                        Image(systemName: "trash")
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
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                SottoPageHeader(title: title, description: description)
                content
            }
            .frame(maxWidth: 780, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
    }
}

private struct SottoEmptyState: View {
    @Environment(\.sottoTheme) private var theme
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(theme.colors.subtleForeground)
            Text(title)
                .font(theme.typography.label)
            Text(description)
                .font(theme.typography.body)
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
