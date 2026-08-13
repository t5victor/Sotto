import AppKit
import Combine
import ServiceManagement
import SottoCore

@MainActor
protocol SottoOverlayPresenting: AnyObject {
    func show()
    func hide()
}

@MainActor
final class SottoAppModel: ObservableObject {
    @Published var preferences: SottoPreferences = .default {
        didSet {
            guard didLoadPreferences else { return }
            persistPreferences()
            if oldValue.shortcut != preferences.shortcut {
                configureHotKey()
            }
        }
    }

    @Published private(set) var modelState: SottoModelState = .checking
    @Published private(set) var dictationState: SottoDictationState = .idle
    @Published private(set) var microphonePermission: SottoPermissionStatus = .notDetermined
    @Published private(set) var accessibilityPermission: SottoPermissionStatus = .notDetermined
    @Published private(set) var audioLevel: Double = 0
    @Published private(set) var history: [TranscriptionRecord] = []
    @Published private(set) var vocabulary: [VocabularyEntry] = []
    @Published private(set) var lastTranscript: String?
    @Published private(set) var hotKeyError: String?
    @Published private(set) var notice: String?
    @Published private(set) var launchAtLoginMessage: String?

    private let directories: SottoDirectories
    private let settingsStore: JSONFileStore<SottoPreferences>
    private let historyRepository: SottoHistoryRepository
    private let vocabularyRepository: SottoVocabularyRepository
    private let parakeet: ParakeetService
    private let recorder: MicrophoneRecorder
    private let inserter: TextInsertionService
    private let hotKeyMonitor: GlobalHotKeyMonitor
    private let postProcessor = TextPostProcessor()

    private weak var overlayPresenter: SottoOverlayPresenting?
    private var didStart = false
    private var didLoadPreferences = false
    private var currentRecordingURL: URL?
    private var currentTarget: InsertionTargetInfo?
    private var modelUpdatesTask: Task<Void, Never>?
    private var microphoneEventsTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var preferenceSaveTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var isHoldShortcutPressed = false
    private var stopWhenRecorderStarts = false

    init(directories: SottoDirectories = .live) {
        self.directories = directories
        self.settingsStore = JSONFileStore(
            url: directories.preferencesFile,
            defaultValue: .default,
            managedRoot: directories.root,
            managedDirectory: directories.state
        )
        self.historyRepository = SottoHistoryRepository(
            url: directories.historyFile,
            managedRoot: directories.root,
            managedDirectory: directories.state
        )
        self.vocabularyRepository = SottoVocabularyRepository(
            url: directories.vocabularyFile,
            managedRoot: directories.root,
            managedDirectory: directories.state
        )
        self.parakeet = ParakeetService(directories: directories)
        self.recorder = MicrophoneRecorder()
        self.inserter = TextInsertionService()
        self.hotKeyMonitor = GlobalHotKeyMonitor()

        hotKeyMonitor.onPressed = { [weak self] in
            self?.handleHotKeyPressed()
        }
        hotKeyMonitor.onReleased = { [weak self] in
            self?.handleHotKeyReleased()
        }
    }

    deinit {
        modelUpdatesTask?.cancel()
        microphoneEventsTask?.cancel()
        downloadTask?.cancel()
        resetTask?.cancel()
        preferenceSaveTask?.cancel()
        preparationTask?.cancel()
        transcriptionTask?.cancel()
    }

    var isListening: Bool { dictationState.isListening }
    var isBusy: Bool { dictationState.isBusy }

    var canStartDictation: Bool {
        modelState.isReady && !dictationState.isBusy
    }

    func attachOverlayPresenter(_ presenter: SottoOverlayPresenting) {
        overlayPresenter = presenter
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        observeModelUpdates()
        observeMicrophoneEvents()

        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    func shutdown() async {
        hotKeyMonitor.unregisterHotKey()
        let activeDownload = downloadTask
        let activeTranscription = transcriptionTask
        downloadTask?.cancel()
        preparationTask?.cancel()
        transcriptionTask?.cancel()
        if recorder.isRecording {
            recorder.cancel()
        }
        overlayPresenter?.hide()
        await activeDownload?.value
        await activeTranscription?.value
        cleanupCurrentRecording()
        preferenceSaveTask?.cancel()
        do {
            try await settingsStore.save(preferences)
        } catch {
            notice = "No se pudieron guardar los ajustes al cerrar: \(Self.userMessage(for: error))"
        }
        await parakeet.unload()
    }

    func toggleDictation() {
        if dictationState.isListening {
            beginStopDictation()
        } else if dictationState.canCancel {
            cancelDictation()
        } else if !dictationState.isBusy {
            beginStartDictation(triggeredByHold: false)
        }
    }

    func cancelDictation() {
        guard dictationState.canCancel else { return }
        preparationTask?.cancel()
        preparationTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        if recorder.isRecording {
            recorder.cancel()
        }
        cleanupCurrentRecording()
        dictationState = .idle
        overlayPresenter?.hide()
    }

    func installModel(replacingExisting: Bool = false) {
        guard downloadTask == nil else { return }
        downloadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.downloadTask = nil }
            do {
                try await self.parakeet.install(replacingExisting: replacingExisting)
            } catch is CancellationError {
                return
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func reinstallModel() {
        guard !dictationState.isBusy else { return }
        installModel(replacingExisting: true)
    }

    func cancelModelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    func deleteModel() {
        guard !dictationState.isBusy else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.parakeet.deleteModel()
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func refreshPermissions() {
        microphonePermission = SottoPermissionService.microphoneStatus()
        accessibilityPermission = SottoPermissionService.accessibilityStatus()
    }

    func requestMicrophonePermission() {
        Task { [weak self] in
            guard let self else { return }
            self.microphonePermission = await SottoPermissionService.requestMicrophone()
        }
    }

    func requestAccessibilityPermission() {
        accessibilityPermission = SottoPermissionService.accessibilityStatus(prompt: true)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refreshPermissions()
        }
    }

    func openMicrophoneSettings() {
        openPrivacySettings(anchor: "Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    func updateShortcut(_ shortcut: SottoShortcut) {
        preferences.shortcut = shortcut
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            presentFailure("No se pudo cambiar el inicio de sesión: \(error.localizedDescription)", hideAfter: nil)
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func addVocabulary(spokenForm: String, replacement: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                self.vocabulary = try await self.vocabularyRepository.upsert(
                    VocabularyEntry(spokenForm: spokenForm, replacement: replacement)
                )
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func removeVocabulary(id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                self.vocabulary = try await self.vocabularyRepository.remove(id: id)
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func removeHistory(id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                self.history = try await self.historyRepository.remove(id: id)
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func clearHistory() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.historyRepository.clear()
                self.history = []
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func dismissFailure() {
        guard case .failed = dictationState else { return }
        dictationState = .idle
    }

    func dismissNotice() {
        notice = nil
    }

    private func bootstrap() async {
        do {
            try directories.prepare()
            _ = try directories.removeStaleRecordings(
                olderThan: Date().addingTimeInterval(-24 * 60 * 60)
            )
        } catch {
            presentFailure("No se pudo preparar la carpeta de Sotto: \(error.localizedDescription)", hideAfter: nil)
            return
        }

        preferences = await settingsStore.load()
        didLoadPreferences = true
        history = await historyRepository.load()
        vocabulary = await vocabularyRepository.load()
        refreshLaunchAtLoginStatus()
        refreshPermissions()
        configureHotKey()

        let inspected = await parakeet.inspect()
        if inspected.isInstalled {
            do {
                try await parakeet.prepare()
            } catch {
                // Model state already contains a user-facing recovery message.
            }
        }
    }

    private func startDictation(triggeredByHold: Bool) async {
        guard !dictationState.isBusy else { return }
        guard modelState.isReady else {
            let message = modelState.isInstalled
                ? "El motor todavía se está preparando."
                : "Instala el motor para empezar a dictar."
            presentFailure(message, hideAfter: 2)
            return
        }

        resetTask?.cancel()
        currentTarget = inserter.captureTarget()
        dictationState = .preparing
        microphonePermission = await SottoPermissionService.requestMicrophone()
        guard !Task.isCancelled, case .preparing = dictationState else {
            cleanupCurrentRecording()
            return
        }
        guard microphonePermission.isGranted else {
            cleanupCurrentRecording()
            presentFailure(
                "Sotto necesita permiso para usar el micrófono. Puedes concederlo en Privacidad y seguridad.",
                hideAfter: nil
            )
            return
        }

        let recordingURL = directories.newRecordingURL()
        currentRecordingURL = recordingURL

        do {
            try directories.validateManagedFile(
                recordingURL,
                in: directories.recordings,
                expectedExtension: "caf"
            )
            try recorder.start(
                writingTo: recordingURL,
                maximumDuration: preferences.maximumRecordingDuration
            )
            audioLevel = 0
            dictationState = .listening(startedAt: Date())
            overlayPresenter?.show()
            playSound(named: "Tink")
            if triggeredByHold && (!isHoldShortcutPressed || stopWhenRecorderStarts) {
                stopWhenRecorderStarts = false
                beginStopDictation()
            }
        } catch {
            cleanupCurrentRecording()
            presentFailure(Self.userMessage(for: error), hideAfter: nil)
        }
    }

    private func stopDictation() async {
        guard dictationState.isListening else { return }

        do {
            let audio = try recorder.stop()
            currentRecordingURL = audio.url
            audioLevel = 0
            dictationState = .transcribing
            overlayPresenter?.show()
            playSound(named: "Pop")

            let transcript = try await parakeet.transcribe(
                audioURL: audio.url,
                language: preferences.language
            )
            let processed = postProcessor.process(
                transcript.text,
                preferences: preferences,
                vocabulary: vocabulary
            )
            guard !processed.isEmpty else { throw ParakeetService.ServiceError.emptyTranscript }
            try Task.checkCancellation()

            dictationState = .inserting
            let outcome = await inserter.insert(
                processed,
                automatically: preferences.insertAutomatically
            )
            lastTranscript = processed
            let targetApplication = currentTarget?.applicationName
            let record = TranscriptionRecord(
                text: processed,
                rawText: transcript.text,
                duration: transcript.duration,
                processingTime: transcript.processingTime,
                confidence: transcript.confidence,
                targetApplication: targetApplication,
                insertionOutcome: outcome
            )

            do {
                try removeRecording(at: audio.url)
            } catch {
                notice = "El texto se insertó, pero no se pudo eliminar la grabación temporal: \(Self.userMessage(for: error))"
            }
            currentRecordingURL = nil
            currentTarget = nil
            inserter.clearTarget()
            dictationState = .completed(text: processed, outcome: outcome)
            playSound(named: "Glass")
            scheduleIdleReset(after: 1.25)

            if preferences.keepHistory {
                do {
                    history = try await historyRepository.add(
                        record,
                        limit: preferences.historyLimit
                    )
                } catch {
                    notice = "El texto se insertó, pero no pudo guardarse en el historial: \(Self.userMessage(for: error))"
                }
            }
        } catch is CancellationError {
            cleanupCurrentRecording()
            dictationState = .idle
            overlayPresenter?.hide()
        } catch {
            cleanupCurrentRecording()
            presentFailure(Self.userMessage(for: error), hideAfter: 2.5)
        }
    }

    private func handleHotKeyPressed() {
        if preferences.holdToTalk {
            guard !dictationState.isBusy else { return }
            isHoldShortcutPressed = true
            stopWhenRecorderStarts = false
            beginStartDictation(triggeredByHold: true)
        } else {
            toggleDictation()
        }
    }

    private func handleHotKeyReleased() {
        guard preferences.holdToTalk else { return }
        isHoldShortcutPressed = false
        if case .preparing = dictationState {
            stopWhenRecorderStarts = true
            return
        }
        guard dictationState.isListening else { return }
        beginStopDictation()
    }

    private func observeModelUpdates() {
        let updates = parakeet.updates
        modelUpdatesTask = Task { [weak self] in
            for await state in updates {
                guard !Task.isCancelled else { return }
                self?.modelState = state
            }
        }
    }

    private func observeMicrophoneEvents() {
        let events = recorder.events
        microphoneEventsTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .level(let level):
                    self.audioLevel = level
                case .limitReached:
                    if self.dictationState.isListening {
                        self.notice = "Se alcanzó el límite de grabación de \(Int(self.preferences.maximumRecordingDuration)) segundos. Sotto transcribirá lo capturado."
                        self.beginStopDictation()
                    }
                case .failure(let message):
                    if self.dictationState.isListening {
                        self.recorder.cancel()
                        self.cleanupCurrentRecording()
                        self.presentFailure(message, hideAfter: nil)
                    }
                }
            }
        }
    }

    private func configureHotKey() {
        do {
            try hotKeyMonitor.register(preferences.shortcut)
            hotKeyError = nil
        } catch {
            hotKeyError = Self.userMessage(for: error)
        }
    }

    private func persistPreferences() {
        preferenceSaveTask?.cancel()
        let snapshot = preferences
        preferenceSaveTask = Task { [weak self, settingsStore] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            do {
                try await settingsStore.save(snapshot)
            } catch {
                self?.notice = "No se pudieron guardar los ajustes: \(Self.userMessage(for: error))"
            }
        }
    }

    private func cleanupCurrentRecording() {
        if let currentRecordingURL {
            do {
                try removeRecording(at: currentRecordingURL)
            } catch {
                notice = "No se pudo eliminar una grabación temporal: \(Self.userMessage(for: error))"
            }
        }
        currentRecordingURL = nil
        currentTarget = nil
        inserter.clearTarget()
        isHoldShortcutPressed = false
        stopWhenRecorderStarts = false
        audioLevel = 0
    }

    private func beginStartDictation(triggeredByHold: Bool) {
        guard preparationTask == nil else { return }
        preparationTask = Task { [weak self] in
            guard let self else { return }
            await self.startDictation(triggeredByHold: triggeredByHold)
            self.preparationTask = nil
        }
    }

    private func beginStopDictation() {
        guard transcriptionTask == nil, dictationState.isListening else { return }
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.stopDictation()
            self.transcriptionTask = nil
        }
    }

    private func removeRecording(at url: URL) throws {
        try directories.validateManagedFile(
            url,
            in: directories.recordings,
            expectedExtension: "caf"
        )
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            preferences.launchAtLogin = true
            launchAtLoginMessage = nil
        case .requiresApproval:
            preferences.launchAtLogin = false
            launchAtLoginMessage = "macOS requiere tu aprobación en Ajustes del Sistema > Ítems de inicio."
        case .notRegistered:
            preferences.launchAtLogin = false
            launchAtLoginMessage = nil
        case .notFound:
            preferences.launchAtLogin = false
            launchAtLoginMessage = "macOS no encuentra el elemento de inicio de Sotto."
        @unknown default:
            preferences.launchAtLogin = false
            launchAtLoginMessage = "No se pudo comprobar el estado del inicio de sesión."
        }
    }

    private func presentFailure(_ message: String, hideAfter: TimeInterval?) {
        dictationState = .failed(message: message)
        overlayPresenter?.show()
        if let hideAfter {
            scheduleIdleReset(after: hideAfter)
        }
    }

    private func scheduleIdleReset(after delay: TimeInterval) {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.dictationState = .idle
            self.overlayPresenter?.hide()
        }
    }

    private func playSound(named name: String) {
        guard preferences.playSounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func userMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}
