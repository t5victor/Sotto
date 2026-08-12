import AppKit
import SottoCore
import SwiftUI
import SottoDesignSystem

@MainActor
final class SottoAppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() async -> Void)?
    private var isPreparingToTerminate = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let onTerminate else { return .terminateNow }
        guard !isPreparingToTerminate else { return .terminateLater }
        isPreparingToTerminate = true
        Task { @MainActor in
            await onTerminate()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct SottoApp: App {
    @NSApplicationDelegateAdaptor(SottoAppDelegate.self) private var appDelegate
    @StateObject private var model: SottoAppModel
    private let overlayController: SottoOverlayController

    init() {
        let model = SottoAppModel()
        _model = StateObject(wrappedValue: model)
        overlayController = SottoOverlayController(model: model)
        model.attachOverlayPresenter(overlayController)
        model.start()
    }

    var body: some Scene {
        WindowGroup("Sotto", id: "main") {
            SottoRootView(model: model)
                .sottoTheme(
                    .standard.withAccent(
                        model.accent.color,
                        foreground: model.accent.foregroundColor
                    )
                )
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    appDelegate.onTerminate = { [weak model] in
                        await model?.shutdown()
                    }
                    model.refreshPermissions()
                }
        }
        .defaultSize(width: 1_040, height: 700)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        MenuBarExtra("Sotto", systemImage: model.isListening ? "mic.fill" : "waveform") {
            SottoMenuBarView(model: model)
                .sottoTheme(
                    .standard.withAccent(
                        model.accent.color,
                        foreground: model.accent.foregroundColor
                    )
                )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SottoAppearanceView(model: model)
                .sottoTheme(
                    .standard.withAccent(
                        model.accent.color,
                        foreground: model.accent.foregroundColor
                    )
                )
                .frame(width: 520, height: 390)
        }
    }
}
