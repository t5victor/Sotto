import Foundation
import SottoLocalization

public actor JSONFileStore<Value: Codable & Sendable> {
    public enum StoreError: LocalizedError {
        case parentIsNotDirectory(URL)

        public var errorDescription: String? {
            switch self {
            case .parentIsNotDirectory(let url):
                SottoLocalization.format("error.store.parent_not_directory", url.path)
            }
        }
    }

    private let url: URL
    private let defaultValue: Value
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let managedDirectories: SottoDirectories?
    private let managedDirectory: URL?

    public init(
        url: URL,
        defaultValue: Value,
        fileManager: FileManager = .default,
        managedRoot: URL? = nil,
        managedDirectory: URL? = nil
    ) {
        precondition(
            (managedRoot == nil) == (managedDirectory == nil),
            "managedRoot and managedDirectory must be provided together"
        )
        self.url = url
        self.defaultValue = defaultValue
        self.fileManager = fileManager
        self.managedDirectories = managedRoot.map(SottoDirectories.init(root:))
        self.managedDirectory = managedDirectory

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() -> Value {
        guard validateManagedPath() else { return defaultValue }
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
        try requireManagedPath()
        let parent = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: parent.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            throw StoreError.parentIsNotDirectory(parent)
        }
        if managedDirectories == nil {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
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

    private func validateManagedPath() -> Bool {
        do {
            try requireManagedPath()
            return true
        } catch {
            return false
        }
    }

    private func requireManagedPath() throws {
        guard let managedDirectories, let managedDirectory else { return }
        try managedDirectories.validateManagedDirectory(
            managedDirectory,
            fileManager: fileManager
        )
        try managedDirectories.validateManagedFile(
            url,
            in: managedDirectory,
            expectedExtension: "json",
            fileManager: fileManager
        )
    }
}
