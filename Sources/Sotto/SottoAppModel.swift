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

