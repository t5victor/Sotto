import AppKit
import SwiftUI
import SottoDesignSystem

@MainActor
final class SottoOverlayController: SottoOverlayPresenting {
    private let panel: NSPanel
    private weak var model: SottoAppModel?

    init(model: SottoAppModel) {
        self.model = model
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 398, height: 112),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(
            rootView: SottoOverlayView(model: model)
                .sottoTheme(.standard)
        )
    }

    func show() {
        guard let model else { return }
        panel.contentView = NSHostingView(
            rootView: SottoOverlayView(model: model)
                .sottoTheme(.standard)
        )
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }
        let frame = panel.frame
        let x = visibleFrame.midX - frame.width / 2
        let y = visibleFrame.minY + 52
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct SottoOverlayView: View {
    @ObservedObject var model: SottoAppModel
    @Environment(\.sottoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            stateIcon

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.label)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.overlayForeground)
                    .lineLimit(1)

                Text(subtitle)
                    .font(theme.typography.caption)
                    .tracking(theme.typography.tracking)
                    .foregroundStyle(theme.colors.overlayMutedForeground)
                    .lineLimit(1)
            }

            Spacer(minLength: theme.spacing.sm)

            if model.dictationState.canCancel {
                if model.dictationState.isListening {
                    SottoWaveform(level: model.audioLevel)
                        .frame(width: 64, height: 24)
                }
                Button {
                    model.cancelDictation()
                } label: {
                    SottoIcon("xmark", size: 12)
                }
                .buttonStyle(SottoOverlayIconButtonStyle())
                .help("Cancelar dictado")
            } else if case .failed = model.dictationState {
                Button("Cerrar") {
                    model.dismissFailure()
                }
                .buttonStyle(SottoOverlayTextButtonStyle())
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .frame(width: 350)
        .frame(minHeight: 64)
        .background(theme.colors.overlay)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous)
                .strokeBorder(theme.colors.overlayBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 28, y: 8)
        .padding(24)
    }

    @ViewBuilder
    private var stateIcon: some View {
        let (icon, color): (String, Color) = switch model.dictationState {
        case .preparing: ("mic", theme.colors.accent)
        case .listening: ("mic", theme.colors.accent)
        case .transcribing: ("waveform", theme.colors.accent)
        case .inserting: ("text.cursor", theme.colors.accent)
        case .completed: ("checkmark", theme.colors.success)
        case .failed: ("exclamationmark", theme.colors.destructive)
        case .idle: ("waveform", theme.colors.overlayMutedForeground)
        }

        SottoIcon(icon, size: 14, weight: .medium)
            .foregroundStyle(color)
            .frame(width: 20, height: 20)
    }

    private var title: String {
        switch model.dictationState {
        case .idle: "Listo para dictar"
        case .preparing: "Preparando micrófono"
        case .listening: "Escuchando"
        case .transcribing: "Transcribiendo"
        case .inserting: "Insertando texto"
        case .completed(_, let outcome): outcome.displayName
        case .failed: "No se pudo completar el dictado"
        }
    }

    private var subtitle: String {
        switch model.dictationState {
        case .idle: model.preferences.shortcut.displayName
        case .preparing: "Un momento…"
        case .listening: model.preferences.holdToTalk ? "Suelta el atajo para terminar" : "Pulsa el atajo para terminar"
        case .transcribing: "Transcribiendo"
        case .inserting: "Volviendo a la aplicación anterior"
        case .completed(let text, _): text
        case .failed(let message): message
        }
    }
}

private struct SottoOverlayIconButtonStyle: ButtonStyle {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(theme.colors.overlayMutedForeground)
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? theme.colors.overlayBorder : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.medium)
                    .strokeBorder(theme.colors.overlayBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    }
}

private struct SottoOverlayTextButtonStyle: ButtonStyle {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.label)
            .tracking(theme.typography.tracking)
            .foregroundStyle(theme.colors.overlayForeground)
            .padding(.horizontal, theme.spacing.sm)
            .frame(minHeight: 28)
            .background(configuration.isPressed ? theme.colors.overlayBorder : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.small)
                    .strokeBorder(theme.colors.overlayBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.small))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    }
}

private struct SottoWaveform: View {
    @Environment(\.sottoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                let shape = Double([0.35, 0.55, 0.8, 1, 0.7, 0.92, 0.58, 0.78, 0.4][index])
                Capsule()
                    .fill(theme.colors.accent)
                    .frame(width: 3, height: max(4, 22 * max(0.12, level) * shape))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: theme.motion.fast), value: level)
        .accessibilityHidden(true)
    }
}
