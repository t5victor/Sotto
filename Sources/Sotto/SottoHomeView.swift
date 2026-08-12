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

