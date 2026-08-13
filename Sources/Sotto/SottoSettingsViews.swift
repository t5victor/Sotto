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
            title: "Motor de voz",
            description: "Configura el motor que convierte tu voz en texto."
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("waveform", size: 17)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text("Motor de voz")
                                .font(theme.typography.sectionTitle)
                            Text("Convierte tus dictados en texto.")
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
                            Text("Detectar automáticamente suele funcionar. Elige un idioma si el resultado no es correcto.")
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

                }
            }
        }
        .confirmationDialog(
            "¿Eliminar el motor?",
            isPresented: $confirmsModelDeletion,
            titleVisibility: .visible
        ) {
            Button("Eliminar motor", role: .destructive) {
                model.deleteModel()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes instalarlo de nuevo. Tus ajustes, vocabulario e historial no se borrarán.")
        }
        .confirmationDialog(
            "¿Reinstalar el motor?",
            isPresented: $confirmsModelRepair,
            titleVisibility: .visible
        ) {
            Button("Reinstalar motor", role: .destructive) {
                model.reinstallModel()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán los archivos actuales y se instalará una copia nueva.")
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
                Button("Instalar motor") {
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
                Button("Reinstalar motor") {
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
                Button("Eliminar motor") {
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
            description: "Corrige nombres y términos que el dictado reconoce mal."
        ) {
            SottoCard {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader(
                        "Añadir término",
                        description: "Escribe lo que dices y cómo quieres que aparezca."
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
                            systemImage: "book.closed",
                            title: "Aún no hay términos",
                            description: "Añade nombres o palabras que suelas dictar."
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
            description: "Inicia y detén el dictado con el teclado."
        ) {
            SottoCard {
                VStack(spacing: theme.spacing.lg) {
                    HStack(spacing: theme.spacing.md) {
                        SottoIcon("command", size: 15)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Atajo global")
                                .font(theme.typography.label)
                            Text("Funciona aunque Sotto no esté en primer plano.")
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
                        description: "Suelta el atajo para terminar.",
                        systemImage: "hand.tap",
                        isOn: $model.preferences.holdToTalk
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Sonidos de estado",
                        description: "Reproduce un sonido al empezar y terminar.",
                        systemImage: "speaker.wave.2",
                        isOn: $model.preferences.playSounds
                    )
                    SottoDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Límite de grabación")
                                .font(theme.typography.label)
                            Text("Sotto detendrá el dictado al alcanzarlo.")
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
            description: "Elige el color de acento de la interfaz."
        ) {
            SottoCard(style: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    SottoSectionHeader("Color de acento")

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
            description: "Decide qué permisos y datos usa Sotto."
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
                        description: "Si está desactivado, Sotto copia el texto.",
                        systemImage: "text.cursor",
                        isOn: $model.preferences.insertAutomatically
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Guardar historial",
                        description: "Conserva tus últimos dictados.",
                        systemImage: "clock",
                        isOn: $model.preferences.keepHistory
                    )
                    SottoDivider()
                    SottoToggleRow(
                        "Abrir al iniciar sesión",
                        description: "Sotto estará disponible al iniciar el Mac.",
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
#if DEBUG
                    SottoDivider()
                    HStack(alignment: .center, spacing: theme.spacing.md) {
                        SottoIcon("arrow.counterclockwise", size: 13, weight: .medium)
                            .foregroundStyle(theme.colors.subtleForeground)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Desarrollo")
                                .font(theme.typography.label)
                                .foregroundStyle(theme.colors.foreground)
                            Text("Vuelve a mostrar el onboarding en esta compilación.")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.mutedForeground)
                        }

                        Spacer(minLength: theme.spacing.lg)

                        Button("Repetir onboarding") {
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
            description: "Revisa, copia o elimina tus dictados."
        ) {
            if model.history.isEmpty {
                SottoCard {
                    SottoEmptyState(
                        systemImage: "clock",
                        title: "Aún no hay dictados",
                        description: "Cuando termines uno, aparecerá aquí."
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

                LazyVStack(spacing: 0) {
                    ForEach(model.history) { record in
                        SottoCard {
                            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                                HStack(spacing: theme.spacing.sm) {
                                    Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.mutedForeground)
                                    if let app = record.targetApplication {
                                        Text(app)
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.subtleForeground)
                                    }
                                    Text(record.insertionOutcome.displayName)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.subtleForeground)
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
                            }
                        }
                        if record.id != model.history.last?.id {
                            SottoDivider()
                                .padding(.horizontal, theme.spacing.md)
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
