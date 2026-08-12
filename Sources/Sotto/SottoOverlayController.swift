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
                .sottoTheme(.standard.withAccent(model.accent.color))
        )
    }

    func show() {
        guard let model else { return }
        panel.contentView = NSHostingView(
            rootView: SottoOverlayView(model: model)
                .sottoTheme(.standard.withAccent(model.accent.color))
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

