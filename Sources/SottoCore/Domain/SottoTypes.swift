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

    public init(
        accent: SottoAccent = .violet,
        language: SottoLanguage = .automatic,
        removeFillers: Bool = true,
        normalizeText: Bool = true,
        insertAutomatically: Bool = true,
        keepHistory: Bool = true,
        historyLimit: Int = 100,
        playSounds: Bool = true,
        launchAtLogin: Bool = false,
        holdToTalk: Bool = true,
        shortcut: SottoShortcut = .defaultDictation
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
    }

    public static let `default` = SottoPreferences()
}
