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
    private var isHoldShortcutPressed = false
    private var stopWhenRecorderStarts = false

    init(directories: SottoDirectories = .live) {
        self.directories = directories
        self.settingsStore = JSONFileStore(
            url: directories.preferencesFile,
            defaultValue: .default
        )
        self.historyRepository = SottoHistoryRepository(url: directories.historyFile)
        self.vocabularyRepository = SottoVocabularyRepository(url: directories.vocabularyFile)
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
    }

    var accent: SottoAccent { preferences.accent }
    var isListening: Bool { dictationState.isListening }
    var isBusy: Bool { dictationState.isBusy }

    var canStartDictation: Bool {
        modelState.isReady && !dictationState.isBusy
    }

    var modelSizeDescription: String? {
        let bytes: Int64
        switch modelState {
        case .installed(let value), .ready(let value): bytes = value
        default: return nil
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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

    func shutdown() {
        hotKeyMonitor.unregisterHotKey()
        downloadTask?.cancel()
        if recorder.isRecording {
            recorder.cancel()
        }
        overlayPresenter?.hide()
        Task { await parakeet.unload() }
    }

    func toggleDictation() {
        if dictationState.isListening {
            Task { [weak self] in await self?.stopDictation() }
        } else if !dictationState.isBusy {
            Task { [weak self] in await self?.startDictation(triggeredByHold: false) }
        }
    }

    func cancelDictation() {
        guard dictationState.isListening else { return }
        recorder.cancel()
        currentRecordingURL = nil
        currentTarget = nil
        inserter.clearTarget()
        isHoldShortcutPressed = false
        stopWhenRecorderStarts = false
        audioLevel = 0
        dictationState = .idle
        overlayPresenter?.hide()
    }

    func installModel() {
        guard downloadTask == nil else { return }
        downloadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.downloadTask = nil }
            do {
                try await self.parakeet.install()
            } catch is CancellationError {
                return
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
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
            preferences.launchAtLogin = enabled
        } catch {
            presentFailure("No se pudo cambiar el inicio de sesión: \(error.localizedDescription)", hideAfter: nil)
        }
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
        preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
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
                ? "Parakeet todavía se está preparando."
                : "Descarga Parakeet para empezar a dictar."
            presentFailure(message, hideAfter: 2)
            return
        }

        dictationState = .preparing
        microphonePermission = await SottoPermissionService.requestMicrophone()
        guard microphonePermission.isGranted else {
            presentFailure(
                "Sotto necesita permiso para usar el micrófono. Puedes concederlo en Privacidad y seguridad.",
                hideAfter: nil
            )
            return
        }

        resetTask?.cancel()
        currentTarget = inserter.captureTarget()
        let recordingURL = directories.newRecordingURL()
        currentRecordingURL = recordingURL

        do {
            try recorder.start(writingTo: recordingURL)
            audioLevel = 0
            dictationState = .listening(startedAt: Date())
            overlayPresenter?.show()
            playSound(named: "Tink")
            if triggeredByHold && (!isHoldShortcutPressed || stopWhenRecorderStarts) {
                stopWhenRecorderStarts = false
                await stopDictation()
            }
        } catch {
            currentRecordingURL = nil
            currentTarget = nil
            inserter.clearTarget()
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

            dictationState = .inserting
            let outcome = await inserter.insert(
                processed,
                automatically: preferences.insertAutomatically
            )
            lastTranscript = processed

            if preferences.keepHistory {
                let record = TranscriptionRecord(
                    text: processed,
                    rawText: transcript.text,
                    duration: transcript.duration,
                    processingTime: transcript.processingTime,
                    confidence: transcript.confidence,
                    targetApplication: currentTarget?.applicationName,
                    insertionOutcome: outcome
                )
                history = try await historyRepository.add(
                    record,
                    limit: preferences.historyLimit
                )
            }

            try? FileManager.default.removeItem(at: audio.url)
            currentRecordingURL = nil
            currentTarget = nil
            dictationState = .completed(text: processed, outcome: outcome)
            playSound(named: "Glass")
            scheduleIdleReset(after: 1.25)
        } catch {
            cleanupCurrentRecording()
            presentFailure(Self.userMessage(for: error), hideAfter: 2.5)
        }
    }

