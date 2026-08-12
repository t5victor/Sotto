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

