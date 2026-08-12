import Foundation

public actor JSONFileStore<Value: Codable & Sendable> {
    public enum StoreError: LocalizedError {
        case parentIsNotDirectory(URL)

        public var errorDescription: String? {
            switch self {
            case .parentIsNotDirectory(let url):
                "No se puede guardar el estado porque \(url.path) no es una carpeta."
            }
        }
    }

    private let url: URL
    private let defaultValue: Value
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(url: URL, defaultValue: Value, fileManager: FileManager = .default) {
        self.url = url
        self.defaultValue = defaultValue
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() -> Value {
        guard fileManager.fileExists(atPath: url.path) else { return defaultValue }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Value.self, from: data)
        } catch {
            preserveCorruptFile()
            return defaultValue
        }
    }

    public func save(_ value: Value) throws {
        let parent = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: parent.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            throw StoreError.parentIsNotDirectory(parent)
        }
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func preserveCorruptFile() {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(timestamp).json")
        try? fileManager.moveItem(at: url, to: backup)
    }
}

