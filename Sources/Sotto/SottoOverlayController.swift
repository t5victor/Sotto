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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 86),
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
                .sottoTheme(
                    .standard.withAccent(
                        model.accent.color,
                        foreground: model.accent.foregroundColor
                    )
                )
        )
    }

    func show() {
        guard let model else { return }
        panel.contentView = NSHostingView(
            rootView: SottoOverlayView(model: model)
                .sottoTheme(
                    .standard.withAccent(
                        model.accent.color,
                        foreground: model.accent.foregroundColor
                    )
                )
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
                    .foregroundStyle(theme.colors.foreground)
                    .lineLimit(1)

                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.mutedForeground)
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
                    Image(systemName: "xmark")
                }
                .buttonStyle(.sotto(.ghost, size: .small))
                .help("Cancelar dictado")
            } else if case .failed = model.dictationState {
                Button("Cerrar") {
                    model.dismissFailure()
                }
                .buttonStyle(.sotto(.ghost, size: .small))
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .frame(width: 350)
        .frame(minHeight: 64)
        .background(.ultraThickMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.85))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .padding(10)
    }

    @ViewBuilder
    private var stateIcon: some View {
        let (icon, color): (String, Color) = switch model.dictationState {
        case .preparing: ("mic", theme.colors.accent)
        case .listening: ("mic.fill", theme.colors.accent)
        case .transcribing: ("waveform.badge.magnifyingglass", theme.colors.accent)
        case .inserting: ("text.cursor", theme.colors.accent)
        case .completed: ("checkmark", theme.colors.successForeground)
        case .failed: ("exclamationmark", theme.colors.destructiveForeground)
        case .idle: ("waveform", theme.colors.mutedForeground)
        }

        Image(systemName: icon)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private var title: String {
        switch model.dictationState {
        case .idle: "Sotto está listo"
        case .preparing: "Preparando micrófono"
        case .listening: "Escuchando"
        case .transcribing: "Transcribiendo en este Mac"
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
        case .transcribing: "Parakeet TDT 0.6B v3"
        case .inserting: "Volviendo a la aplicación anterior"
        case .completed(let text, _): text
        case .failed(let message): message
        }
    }
}

private struct SottoWaveform: View {
    @Environment(\.sottoTheme) private var theme
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
        .animation(.easeOut(duration: theme.motion.fast), value: level)
        .accessibilityHidden(true)
    }
}
