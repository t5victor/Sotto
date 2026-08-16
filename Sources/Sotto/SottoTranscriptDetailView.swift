import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

struct SottoTranscriptDetailView: View {
    let record: TranscriptionRecord
    @ObservedObject var model: SottoAppModel
    let onBack: () -> Void

    @Environment(\.sottoTheme) private var theme

    private var recordProject: SottoProject? {
        model.projects.first(where: { $0.id == record.projectID })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                SottoReveal {
                    Button(action: onBack) {
                        HStack(spacing: theme.spacing.xs) {
                            SottoIcon("chevron.left", size: 12, weight: .semibold)
                            Text(SottoLocalization.string("common.back"))
                        }
                    }
                    .buttonStyle(.sotto(.ghost, size: .small))
                    .accessibilityLabel(SottoLocalization.string("common.back"))
                }

                SottoReveal(delay: 0.04) {
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        HStack(alignment: .top, spacing: theme.spacing.lg) {
                            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                                Text(SottoLocalization.string("transcription.detail.title"))
                                    .font(theme.typography.pageTitle)
                                    .tracking(-0.42)
                                    .foregroundStyle(theme.colors.foreground)

                                metadata
                            }

                            Spacer(minLength: theme.spacing.md)

                            SottoTranscriptActionBar(
                                record: record,
                                model: model,
                                projectID: record.projectID
                            )
                        }

                        SottoDivider()

                        Text(record.text)
                            .font(.system(size: 18, weight: .regular))
                            .tracking(theme.typography.tracking)
                            .lineSpacing(5)
                            .foregroundStyle(theme.colors.foreground)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(theme.spacing.xxl)
        }
        .background(theme.colors.surface)
    }

    private var metadata: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(record.createdAt, format: .dateTime.day().month().year().hour().minute())
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

            if let recordProject {
                HStack(spacing: theme.spacing.xxs) {
                    SottoIcon(recordProject.icon, size: 11)
                        .foregroundStyle(recordProject.accent.themePalette.background.color)
                    Text(recordProject.name)
                }
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.subtleForeground)
            }
        }
        .lineLimit(1)
    }
}
