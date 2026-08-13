import AppKit
import SottoCore
import SottoDesignSystem
import SottoLocalization
import SwiftUI

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
        SottoFontRegistry.registerBundledFonts()
        let model = SottoAppModel()
        _model = StateObject(wrappedValue: model)
        overlayController = SottoOverlayController(model: model)
        model.attachOverlayPresenter(overlayController)
        model.start()
    }

    var body: some Scene {
        WindowGroup(SottoLocalization.string("app.name"), id: "main") {
            SottoAppContentView(model: model)
                .sottoTheme(.standard)
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

        MenuBarExtra(SottoLocalization.string("app.name"), systemImage: model.isListening ? "mic" : "waveform") {
            SottoMenuBarView(model: model)
                .sottoTheme(.standard)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SottoAppearanceView(model: model)
                .sottoTheme(.standard)
                .frame(width: 520, height: 390)
        }
    }
}
