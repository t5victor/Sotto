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
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text("Sotto")
                        .font(theme.typography.sectionTitle)
                    Text("Parakeet TDT 0.6B v3 · Local")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.mutedForeground)
                }
                Spacer()
                SottoBadge(statusLabel, tone: statusTone)
            }

            SottoRecordingPill(
                state: recordingState,
                level: model.audioLevel
            )
            .frame(maxWidth: .infinity)

            if !model.modelState.isReady {
                Text(model.modelState.detail)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(model.isListening ? "Detener dictado" : "Empezar a dictar") {
                model.toggleDictation()
            }
            .buttonStyle(.sotto(model.isListening ? .secondary : .primary, expands: true))
            .disabled(!model.isListening && !model.canStartDictation)

            if let transcript = model.lastTranscript {
                Button {
                    model.copyToPasteboard(transcript)
                } label: {
                    Label("Copiar último dictado", systemImage: "doc.on.doc")
                }
                .buttonStyle(.sotto(.secondary, size: .small, expands: true))
            }

            Divider()

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
        .frame(width: 310)
    }

    private var statusLabel: String {
        switch model.dictationState {
        case .listening: "Escuchando"
        case .transcribing, .inserting: "Procesando"
        case .failed: "Error"
        default: model.modelState.title
        }
    }

    private var statusTone: SottoBadgeTone {
        switch model.dictationState {
        case .failed: .destructive
        case .listening, .transcribing, .inserting: .accent
        default: model.modelState.tone
        }
    }

    private var recordingState: SottoRecordingState {
        switch model.dictationState {
        case .listening: .listening
        case .transcribing, .inserting: .transcribing
        default: .idle
        }
    }
}

