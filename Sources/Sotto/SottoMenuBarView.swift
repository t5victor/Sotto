import AppKit
import SottoCore
import SottoDesignSystem
import SwiftUI

struct SottoMenuBarView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.sm) {
                SottoIcon("waveform", size: 14, weight: .medium)
                    .foregroundStyle(theme.colors.accentInk)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text("Sotto")
                        .font(theme.typography.sectionTitle)
                        .tracking(theme.typography.tracking)
                }
                Spacer()
            }

            if model.dictationState == .transcribing || model.dictationState == .inserting {
                SottoCard(style: .muted, padding: theme.spacing.md) {
                    SottoActivityLabel(
                        model.dictationState == .inserting ? "Insertando texto" : "Transcribiendo"
                    )
                }
            } else if model.modelState.isReady {
                SottoRecordingPill(
                    state: recordingState,
                    level: model.audioLevel
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !model.modelState.isReady {
                Text(model.modelState.detail)
                    .font(theme.typography.caption)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(menuActionTitle) {
                model.toggleDictation()
            }
            .buttonStyle(.sotto(model.isListening ? .secondary : .primary, expands: true))
            .disabled(!model.dictationState.canCancel && !model.canStartDictation)

            if let transcript = model.lastTranscript {
                Button {
                    model.copyToPasteboard(transcript)
                } label: {
                    HStack(spacing: theme.spacing.sm) {
                        SottoIcon("doc.on.doc", size: 13)
                        Text("Copiar último dictado")
                    }
                }
                .buttonStyle(.sotto(.secondary, size: .small, expands: true))
            }

            SottoDivider()

            HStack {
                Button("Abrir Sotto") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                .buttonStyle(.sotto(.ghost, size: .small))

                Spacer()

                Button("Salir") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.sotto(.ghost, size: .small))
            }
        }
        .padding(theme.spacing.lg)
        .frame(width: 320)
        .background(theme.colors.surface)
    }

    private var recordingState: SottoRecordingState {
        switch model.dictationState {
        case .listening: .listening
        case .transcribing, .inserting: .transcribing
        default: .idle
        }
    }

    private var menuActionTitle: String {
        if model.isListening { return "Detener dictado" }
        if model.dictationState.canCancel { return "Cancelar dictado" }
        return "Empezar a dictar"
    }
}
