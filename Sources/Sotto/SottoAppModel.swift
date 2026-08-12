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

