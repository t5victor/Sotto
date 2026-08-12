import AppKit
import SottoCore
import SwiftUI
import SottoDesignSystem

@MainActor
final class SottoAppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
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
                .sottoTheme(.standard.withAccent(model.accent.color))
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    appDelegate.onTerminate = { [weak model] in
                        model?.shutdown()
                    }
                    model.refreshPermissions()
                }
        }
        .defaultSize(width: 1_040, height: 700)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        MenuBarExtra("Sotto", systemImage: model.isListening ? "mic.fill" : "waveform") {
            SottoMenuBarView(model: model)
                .sottoTheme(.standard.withAccent(model.accent.color))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SottoAppearanceView(model: model)
                .sottoTheme(.standard.withAccent(model.accent.color))
                .frame(width: 520, height: 390)
        }
    }
}
