import SottoCore
import SottoDesignSystem
import SwiftUI

struct SottoModelsView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme
    @State private var confirmsModelDeletion = false

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
    }

    @ViewBuilder
