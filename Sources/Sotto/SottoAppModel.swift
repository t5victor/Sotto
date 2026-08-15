import AppKit
import Combine
import ServiceManagement
import SottoCore
import SottoLocalization

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
    @Published private(set) var projects: [SottoProject] = []
    @Published private(set) var captureProjectID: UUID? = nil
    @Published private(set) var vocabulary: [VocabularyEntry] = []
    @Published private(set) var lastTranscript: String?
    @Published private(set) var hotKeyError: String?
    @Published private(set) var notice: String?
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var isBootstrapped = false
    @Published private(set) var canRetryDictation = false

    private let directories: SottoDirectories
    private let settingsStore: JSONFileStore<SottoPreferences>
    private let historyRepository: SottoHistoryRepository
    private let projectRepository: SottoProjectRepository
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
        self.projectRepository = SottoProjectRepository(
            url: directories.projectsFile,
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
        modelState.isReady && !dictationState.isBusy && !canRetryDictation
    }

    func setCaptureProject(_ projectID: UUID?) {
        guard let projectID else {
            captureProjectID = nil
            return
        }

        guard projects.contains(where: { $0.id == projectID }) else { return }
        captureProjectID = projectID
    }

    var shouldShowOnboarding: Bool {
        isBootstrapped && !preferences.hasCompletedOnboarding
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }

#if DEBUG
    // TODO(release): remove this local onboarding reset before production release.
    func resetOnboardingForDebug() {
        preferences.hasCompletedOnboarding = false
    }
#endif

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
            notice = SottoLocalization.format(
                "error.app.save_on_exit",
                Self.userMessage(for: error)
            )
        }
        await parakeet.unload()
    }

    func toggleDictation() {
        if dictationState.isListening {
            beginStopDictation()
        } else if dictationState.canCancel {
            cancelDictation()
        } else if !dictationState.isBusy && !canRetryDictation {
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
            presentFailure(
                SottoLocalization.format("error.app.login_item", error.localizedDescription),
                hideAfter: nil
            )
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

    @discardableResult
    func createProject(
        name: String,
        icon: String = "folder",
        accent: SottoAccent = .blue
    ) -> SottoProject? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let project = SottoProject(name: trimmedName, icon: icon, accent: accent)
        projects.insert(project, at: 0)
        persistProject(project)
        return project
    }

    func updateProject(id: UUID, name: String, icon: String, accent: SottoAccent) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let existing = projects[index]
        projects[index] = SottoProject(
            id: existing.id,
            name: trimmedName,
            icon: icon,
            accent: accent,
            createdAt: existing.createdAt
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                self.projects = try await self.projectRepository.update(
                    id: id,
                    name: trimmedName,
                    icon: icon,
                    accent: accent
                )
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
                self.projects = await self.projectRepository.load()
            }
        }
    }

    func deleteProject(id: UUID) {
        if captureProjectID == id {
            captureProjectID = nil
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.history = try await self.historyRepository.moveAll(from: id, to: nil)
                self.projects = try await self.projectRepository.remove(id: id)
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
                self.history = await self.historyRepository.load()
                self.projects = await self.projectRepository.load()
            }
        }
    }

    func moveHistory(id: UUID, to projectID: UUID?) {
        guard projectID == nil || projects.contains(where: { $0.id == projectID }) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                self.history = try await self.historyRepository.move(id: id, to: projectID)
            } catch {
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    func toggleHistoryPin(id: UUID) {
        guard let record = history.first(where: { $0.id == id }) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                self.history = try await self.historyRepository.setPinned(id: id, isPinned: !record.isPinned)
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
        resetTask?.cancel()
        if canRetryDictation {
            cleanupCurrentRecording()
        }
        canRetryDictation = false
        dictationState = .idle
        overlayPresenter?.hide()
    }

    func retryFailedDictation() {
        guard canRetryDictation,
              case .failed = dictationState,
              let recordingURL = currentRecordingURL,
              FileManager.default.fileExists(atPath: recordingURL.path)
        else {
            dismissFailure()
            return
        }

        resetTask?.cancel()
        canRetryDictation = false
        dictationState = .transcribing
        overlayPresenter?.show()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.transcribeRecording(at: recordingURL)
            self.transcriptionTask = nil
        }
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
            presentFailure(
                SottoLocalization.format("error.app.prepare_directory", error.localizedDescription),
                hideAfter: nil
            )
            isBootstrapped = true
            return
        }

        preferences = await settingsStore.load()
        didLoadPreferences = true
        history = await historyRepository.load()
        projects = await projectRepository.load()
        vocabulary = await vocabularyRepository.load()
        refreshLaunchAtLoginStatus()
        refreshPermissions()
        configureHotKey()

        let inspected = await parakeet.inspect()
        isBootstrapped = true
        if inspected.isInstalled {
            do {
                try await parakeet.prepare()
            } catch {
                // Model state already contains a user-facing recovery message.
            }
        }
    }

    private func startDictation(triggeredByHold: Bool) async {
        guard !dictationState.isBusy, !canRetryDictation else { return }
        guard modelState.isReady else {
            let message = modelState.isInstalled
                ? SottoLocalization.string("error.app.model_preparing")
                : SottoLocalization.string("error.app.model_required")
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
                SottoLocalization.string("error.app.microphone_permission"),
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
            await transcribeRecording(at: audio.url)
        } catch is CancellationError {
            cleanupCurrentRecording()
            dictationState = .idle
            overlayPresenter?.hide()
        } catch {
            cleanupCurrentRecording()
            presentFailure(Self.userMessage(for: error), hideAfter: 2.5)
        }
    }

    private func transcribeRecording(at audioURL: URL) async {
        do {
            let transcript = try await parakeet.transcribe(
                audioURL: audioURL,
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
                insertionOutcome: outcome,
                projectID: captureProjectID
            )

            do {
                try removeRecording(at: audioURL)
            } catch {
                notice = SottoLocalization.format(
                    "notice.app.remove_recording",
                    Self.userMessage(for: error)
                )
            }
            currentRecordingURL = nil
            currentTarget = nil
            inserter.clearTarget()
            canRetryDictation = false
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
                    notice = SottoLocalization.format(
                        "notice.app.save_history",
                        Self.userMessage(for: error)
                    )
                }
            }
        } catch is CancellationError {
            cleanupCurrentRecording()
            dictationState = .idle
            overlayPresenter?.hide()
        } catch let error as ParakeetService.ServiceError where error.preservesRecordingForRetry {
            canRetryDictation = true
            presentFailure(Self.userMessage(for: error), hideAfter: nil)
        } catch {
            cleanupCurrentRecording()
            presentFailure(Self.userMessage(for: error), hideAfter: 2.5)
        }
    }

    private func handleHotKeyPressed() {
        if preferences.holdToTalk {
            guard !dictationState.isBusy, !canRetryDictation else { return }
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
                        self.notice = SottoLocalization.format(
                            "notice.app.recording_limit",
                            Int64(self.preferences.maximumRecordingDuration)
                        )
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
                self?.notice = SottoLocalization.format(
                    "error.app.save_preferences",
                    Self.userMessage(for: error)
                )
            }
        }
    }

    private func persistProject(_ project: SottoProject) {
        Task { [weak self] in
            guard let self else { return }
            do {
                self.projects = try await self.projectRepository.add(project)
            } catch {
                self.projects.removeAll { $0.id == project.id }
                self.presentFailure(Self.userMessage(for: error), hideAfter: nil)
            }
        }
    }

    private func cleanupCurrentRecording() {
        if let currentRecordingURL {
            do {
                try removeRecording(at: currentRecordingURL)
            } catch {
                notice = SottoLocalization.format(
                    "error.app.remove_recording",
                    Self.userMessage(for: error)
                )
            }
        }
        currentRecordingURL = nil
        currentTarget = nil
        canRetryDictation = false
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
            launchAtLoginMessage = SottoLocalization.string("app.login.requires_approval")
        case .notRegistered:
            preferences.launchAtLogin = false
            launchAtLoginMessage = nil
        case .notFound:
            preferences.launchAtLogin = false
            launchAtLoginMessage = SottoLocalization.string("app.login.not_found")
        @unknown default:
            preferences.launchAtLogin = false
            launchAtLoginMessage = SottoLocalization.string("app.login.unknown")
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
