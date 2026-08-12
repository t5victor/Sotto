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
