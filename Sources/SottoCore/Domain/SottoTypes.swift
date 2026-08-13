import Foundation

public enum SottoAccent: String, Codable, CaseIterable, Identifiable, Sendable {
    case violet
    case blue
    case coral
    case green

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .violet: "Violeta"
        case .blue: "Azul"
        case .coral: "Coral"
        case .green: "Verde"
        }
    }
}

/// Languages supported by Parakeet TDT 0.6B v3.
public enum SottoLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case bulgarian = "bg"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case estonian = "et"
    case finnish = "fi"
    case french = "fr"
    case german = "de"
    case greek = "el"
    case hungarian = "hu"
    case italian = "it"
    case latvian = "lv"
    case lithuanian = "lt"
    case maltese = "mt"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case spanish = "es"
    case swedish = "sv"
    case ukrainian = "uk"

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .automatic: "Detectar automáticamente"
        case .bulgarian: "Búlgaro"
        case .croatian: "Croata"
        case .czech: "Checo"
        case .danish: "Danés"
        case .dutch: "Neerlandés"
        case .english: "Inglés"
        case .estonian: "Estonio"
        case .finnish: "Finés"
        case .french: "Francés"
        case .german: "Alemán"
        case .greek: "Griego"
        case .hungarian: "Húngaro"
        case .italian: "Italiano"
        case .latvian: "Letón"
        case .lithuanian: "Lituano"
        case .maltese: "Maltés"
        case .polish: "Polaco"
        case .portuguese: "Portugués"
        case .romanian: "Rumano"
        case .russian: "Ruso"
        case .slovak: "Eslovaco"
        case .slovenian: "Esloveno"
        case .spanish: "Español"
        case .swedish: "Sueco"
        case .ukrainian: "Ucraniano"
        }
    }
}

public struct SottoShortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayName = displayName
    }

    /// Option + Space. Carbon's `optionKey` value is 2048.
    public static let defaultDictation = SottoShortcut(
        keyCode: 49,
        carbonModifiers: 2_048,
        displayName: "⌥ Espacio"
    )
}

public struct SottoPreferences: Codable, Equatable, Sendable {
    public var accent: SottoAccent
    public var language: SottoLanguage
    public var removeFillers: Bool
    public var normalizeText: Bool
    public var insertAutomatically: Bool
    public var keepHistory: Bool
    public var historyLimit: Int
    public var playSounds: Bool
    public var launchAtLogin: Bool
    public var holdToTalk: Bool
    public var shortcut: SottoShortcut
    public var maximumRecordingDuration: TimeInterval
    public var hasCompletedOnboarding: Bool

    public init(
        accent: SottoAccent = .blue,
        language: SottoLanguage = .automatic,
        removeFillers: Bool = true,
        normalizeText: Bool = true,
        insertAutomatically: Bool = true,
        keepHistory: Bool = true,
        historyLimit: Int = 100,
        playSounds: Bool = true,
        launchAtLogin: Bool = false,
        holdToTalk: Bool = true,
        shortcut: SottoShortcut = .defaultDictation,
        maximumRecordingDuration: TimeInterval = 300,
        hasCompletedOnboarding: Bool = false
    ) {
        self.accent = accent
        self.language = language
        self.removeFillers = removeFillers
        self.normalizeText = normalizeText
        self.insertAutomatically = insertAutomatically
        self.keepHistory = keepHistory
        self.historyLimit = min(max(historyLimit, 10), 1_000)
        self.playSounds = playSounds
        self.launchAtLogin = launchAtLogin
        self.holdToTalk = holdToTalk
        self.shortcut = shortcut
        self.maximumRecordingDuration = min(max(maximumRecordingDuration, 30), 1_800)
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public static let `default` = SottoPreferences()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case accent
        case language
        case removeFillers
        case normalizeText
        case insertAutomatically
        case keepHistory
        case historyLimit
        case playSounds
        case launchAtLogin
        case holdToTalk
        case shortcut
        case maximumRecordingDuration
        case hasCompletedOnboarding
    }

    /// Decodes older preference files field by field. Adding a setting no
    /// longer makes the whole file look corrupt and silently reset.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        let storedSchemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        self.init(
            accent: try values.decodeIfPresent(SottoAccent.self, forKey: .accent) ?? defaults.accent,
            language: try values.decodeIfPresent(SottoLanguage.self, forKey: .language) ?? defaults.language,
            removeFillers: try values.decodeIfPresent(Bool.self, forKey: .removeFillers) ?? defaults.removeFillers,
            normalizeText: try values.decodeIfPresent(Bool.self, forKey: .normalizeText) ?? defaults.normalizeText,
            insertAutomatically: try values.decodeIfPresent(Bool.self, forKey: .insertAutomatically)
                ?? defaults.insertAutomatically,
            keepHistory: try values.decodeIfPresent(Bool.self, forKey: .keepHistory) ?? defaults.keepHistory,
            historyLimit: try values.decodeIfPresent(Int.self, forKey: .historyLimit) ?? defaults.historyLimit,
            playSounds: try values.decodeIfPresent(Bool.self, forKey: .playSounds) ?? defaults.playSounds,
            launchAtLogin: try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin,
            holdToTalk: try values.decodeIfPresent(Bool.self, forKey: .holdToTalk) ?? defaults.holdToTalk,
            shortcut: try values.decodeIfPresent(SottoShortcut.self, forKey: .shortcut) ?? defaults.shortcut,
            maximumRecordingDuration: try values.decodeIfPresent(
                TimeInterval.self,
                forKey: .maximumRecordingDuration
            ) ?? defaults.maximumRecordingDuration,
            // Version 4 is the first version that could complete onboarding.
            // Older files, including files written by the initial migration,
            // must see it once instead of being treated as already configured.
            hasCompletedOnboarding: storedSchemaVersion >= 4
                ? (try values.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false)
                : false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(4, forKey: .schemaVersion)
        try values.encode(accent, forKey: .accent)
        try values.encode(language, forKey: .language)
        try values.encode(removeFillers, forKey: .removeFillers)
        try values.encode(normalizeText, forKey: .normalizeText)
        try values.encode(insertAutomatically, forKey: .insertAutomatically)
        try values.encode(keepHistory, forKey: .keepHistory)
        try values.encode(historyLimit, forKey: .historyLimit)
        try values.encode(playSounds, forKey: .playSounds)
        try values.encode(launchAtLogin, forKey: .launchAtLogin)
        try values.encode(holdToTalk, forKey: .holdToTalk)
        try values.encode(shortcut, forKey: .shortcut)
        try values.encode(maximumRecordingDuration, forKey: .maximumRecordingDuration)
        try values.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }
}

public struct VocabularyEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var spokenForm: String
    public var replacement: String

    public init(id: UUID = UUID(), spokenForm: String, replacement: String) {
        self.id = id
        self.spokenForm = spokenForm
        self.replacement = replacement
    }

    public static let sotto = VocabularyEntry(
        id: UUID(uuidString: "5A5B0924-220A-4DA0-8C97-D1B31E39BB85")!,
        spokenForm: "Soto",
        replacement: "Sotto"
    )

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case spokenForm
        case replacement
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            spokenForm: try values.decode(String.self, forKey: .spokenForm),
            replacement: try values.decode(String.self, forKey: .replacement)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .schemaVersion)
        try values.encode(id, forKey: .id)
        try values.encode(spokenForm, forKey: .spokenForm)
        try values.encode(replacement, forKey: .replacement)
    }
}

public struct SottoTranscript: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Float
    public let duration: TimeInterval
    public let processingTime: TimeInterval

    public init(
        text: String,
        confidence: Float,
        duration: TimeInterval,
        processingTime: TimeInterval
    ) {
        self.text = text
        self.confidence = confidence
        self.duration = duration
        self.processingTime = processingTime
    }

    public var realTimeFactor: Double {
        guard processingTime > 0 else { return 0 }
        return duration / processingTime
    }
}

public enum TextInsertionOutcome: String, Codable, Equatable, Sendable {
    case inserted
    case pasted
    case pasteAttempted
    case copied
    case skipped

    public var displayName: String {
        switch self {
        case .inserted: "Insertado"
        case .pasted: "Pegado"
        case .pasteAttempted: "Pegado solicitado"
        case .copied: "Copiado"
        case .skipped: "Sin insertar"
        }
    }
}

public struct TranscriptionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let text: String
    public let rawText: String
    public let duration: TimeInterval
    public let processingTime: TimeInterval
    public let confidence: Float
    public let targetApplication: String?
    public let insertionOutcome: TextInsertionOutcome

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        rawText: String,
        duration: TimeInterval,
        processingTime: TimeInterval,
        confidence: Float,
        targetApplication: String?,
        insertionOutcome: TextInsertionOutcome
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.rawText = rawText
        self.duration = duration
        self.processingTime = processingTime
        self.confidence = confidence
        self.targetApplication = targetApplication
        self.insertionOutcome = insertionOutcome
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case createdAt
        case text
        case rawText
        case duration
        case processingTime
        case confidence
        case targetApplication
        case insertionOutcome
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let text = try values.decode(String.self, forKey: .text)
        self.init(
            id: try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            createdAt: try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            text: text,
            rawText: try values.decodeIfPresent(String.self, forKey: .rawText) ?? text,
            duration: try values.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0,
            processingTime: try values.decodeIfPresent(
                TimeInterval.self,
                forKey: .processingTime
            ) ?? 0,
            confidence: try values.decodeIfPresent(Float.self, forKey: .confidence) ?? 0,
            targetApplication: try values.decodeIfPresent(
                String.self,
                forKey: .targetApplication
            ),
            insertionOutcome: try values.decodeIfPresent(
                TextInsertionOutcome.self,
                forKey: .insertionOutcome
            ) ?? .skipped
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .schemaVersion)
        try values.encode(id, forKey: .id)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(text, forKey: .text)
        try values.encode(rawText, forKey: .rawText)
        try values.encode(duration, forKey: .duration)
        try values.encode(processingTime, forKey: .processingTime)
        try values.encode(confidence, forKey: .confidence)
        try values.encodeIfPresent(targetApplication, forKey: .targetApplication)
        try values.encode(insertionOutcome, forKey: .insertionOutcome)
    }
}

public enum SottoModelState: Equatable, Sendable {
    case checking
    case notInstalled
    case installed(bytes: Int64)
    case downloading(progress: Double, detail: String)
    case validating
    case loading
    case ready(bytes: Int64)
    case failed(message: String)

    public var isInstalled: Bool {
        switch self {
        case .installed, .loading, .ready: true
        default: false
        }
    }

    public var isReady: Bool {
        if case .ready = self { true } else { false }
    }
}

public enum SottoDictationState: Equatable, Sendable {
    case idle
    case preparing
    case listening(startedAt: Date)
    case transcribing
    case inserting
    case completed(text: String, outcome: TextInsertionOutcome)
    case failed(message: String)

    public var isListening: Bool {
        if case .listening = self { true } else { false }
    }

    public var isBusy: Bool {
        switch self {
        case .preparing, .listening, .transcribing, .inserting: true
        default: false
        }
    }

    public var canCancel: Bool {
        switch self {
        case .preparing, .listening, .transcribing:
            true
        default:
            false
        }
    }
}

public enum SottoPermissionStatus: String, Codable, Equatable, Sendable {
    case notDetermined
    case granted
    case denied
    case restricted

    public var isGranted: Bool { self == .granted }
}
