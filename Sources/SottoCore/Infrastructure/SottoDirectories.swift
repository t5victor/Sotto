import Foundation

public enum SottoManagedPathError: LocalizedError, Equatable {
    case outsideRoot(URL)
    case unexpectedChild(URL)
    case unexpectedExtension(URL, String)
    case symbolicLink(URL)
    case notDirectory(URL)

    public var errorDescription: String? {
        switch self {
        case .outsideRoot(let url):
            "La ruta no pertenece a la carpeta privada de Sotto: \(url.path)."
        case .unexpectedChild(let url):
            "Sotto rechazó una ruta de archivo inesperada: \(url.path)."
        case .unexpectedExtension(let url, let expected):
            "Sotto esperaba un archivo .\(expected), no \(url.lastPathComponent)."
        case .symbolicLink(let url):
            "Sotto rechazó un enlace simbólico en una carpeta gestionada: \(url.path)."
        case .notDirectory(let url):
            "La ruta gestionada por Sotto no es una carpeta: \(url.path)."
        }
    }
}

public struct SottoDirectories: Sendable {
    public let root: URL
    public let models: URL
    public let recordings: URL
    public let state: URL
    public let logs: URL

    public init(root: URL) {
        let root = root.standardizedFileURL
        self.root = root
        self.models = root.appendingPathComponent("Models", isDirectory: true)
        self.recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        self.state = root.appendingPathComponent("State", isDirectory: true)
        self.logs = root.appendingPathComponent("Logs", isDirectory: true)
    }

    public static var live: SottoDirectories {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return SottoDirectories(
            root: applicationSupport.appendingPathComponent("Sotto", isDirectory: true)
        )
    }

    public var parakeetV3: URL {
        // FluidAudio drops the remote repository's `-coreml` suffix when it
        // creates the local cache directory.
        models.appendingPathComponent("parakeet-tdt-0.6b-v3", isDirectory: true)
    }

    public var preferencesFile: URL {
        state.appendingPathComponent("preferences.json")
    }

    public var vocabularyFile: URL {
        state.appendingPathComponent("vocabulary.json")
    }

    public var historyFile: URL {
        state.appendingPathComponent("history.json")
    }

    /// Creates only Sotto-owned directories and rejects symbolic-link
    /// substitution at the managed root or any of its direct children.
    public func prepare(fileManager: FileManager = .default) throws {
        try Self.createManagedDirectory(root, root: root, fileManager: fileManager)
        for directory in [models, recordings, state, logs] {
            try Self.createManagedDirectory(directory, root: root, fileManager: fileManager)
        }
    }

    public func newRecordingURL(id: UUID = UUID()) -> URL {
        recordings.appendingPathComponent("\(id.uuidString).caf")
    }

    /// Validates a direct file child without following a symbolic link.
    public func validateManagedFile(
        _ file: URL,
        in directory: URL,
        expectedExtension: String? = nil,
        fileManager: FileManager = .default
    ) throws {
        let candidate = file.standardizedFileURL
        let parent = directory.standardizedFileURL
        try Self.ensureContained(parent, in: root)
        try Self.ensureNoSymbolicLinks(from: root, through: parent, fileManager: fileManager)
        guard candidate.deletingLastPathComponent() == parent else {
            throw SottoManagedPathError.unexpectedChild(candidate)
        }
        if let expectedExtension,
           candidate.pathExtension.lowercased() != expectedExtension.lowercased() {
            throw SottoManagedPathError.unexpectedExtension(candidate, expectedExtension)
        }
        if Self.isSymbolicLink(candidate, fileManager: fileManager) {
            throw SottoManagedPathError.symbolicLink(candidate)
        }
    }

    /// Validates the model cache and every existing descendant. Model loading
    /// must never traverse a link planted inside the otherwise valid cache.
    public func validateModelTree(fileManager: FileManager = .default) throws {
        try validateManagedDirectory(models, fileManager: fileManager)
        let target = parakeetV3.standardizedFileURL
        guard target.deletingLastPathComponent() == models.standardizedFileURL,
              target.lastPathComponent == "parakeet-tdt-0.6b-v3"
        else {
            throw SottoManagedPathError.unexpectedChild(target)
        }
        guard !Self.isSymbolicLink(target, fileManager: fileManager) else {
            throw SottoManagedPathError.symbolicLink(target)
        }
        guard fileManager.fileExists(atPath: target.path) else { return }
        try validateManagedDirectory(target, fileManager: fileManager)
        try Self.ensureTreeContainsNoSymbolicLinks(at: target, fileManager: fileManager)
    }

    public func validateManagedDirectory(
        _ directory: URL,
        fileManager: FileManager = .default
    ) throws {
        let directory = directory.standardizedFileURL
        try Self.ensureContained(directory, in: root)
        try Self.ensureNoSymbolicLinks(from: root, through: directory, fileManager: fileManager)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw SottoManagedPathError.notDirectory(directory)
        }
    }

    /// Removes only stale CAF files from Sotto's recording scratch directory.
    /// A crash can leave one behind, while successful and cancelled dictations
    /// remove their recording immediately.
    @discardableResult
    public func removeStaleRecordings(
        olderThan cutoff: Date,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard fileManager.fileExists(atPath: recordings.path) else { return 0 }
        try validateManagedDirectory(recordings, fileManager: fileManager)

        let files = try fileManager.contentsOfDirectory(
            at: recordings,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var removed = 0
        for file in files where file.pathExtension.lowercased() == "caf" {
            try validateManagedFile(
                file,
                in: recordings,
                expectedExtension: "caf",
                fileManager: fileManager
            )
            let values = try file.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoff
            else { continue }
            try fileManager.removeItem(at: file)
            removed += 1
        }
        return removed
    }

    private static func createManagedDirectory(
        _ directory: URL,
        root: URL,
        fileManager: FileManager
    ) throws {
        let directory = directory.standardizedFileURL
        try ensureContained(directory, in: root)
        if isSymbolicLink(directory, fileManager: fileManager) {
            throw SottoManagedPathError.symbolicLink(directory)
        }
        if fileManager.fileExists(atPath: directory.path) {
            try ensureNoSymbolicLinks(from: root, through: directory, fileManager: fileManager)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                throw SottoManagedPathError.notDirectory(directory)
            }
            return
        }

        if directory != root.standardizedFileURL {
            try ensureNoSymbolicLinks(
                from: root,
                through: directory.deletingLastPathComponent(),
                fileManager: fileManager
            )
        }
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: directory == root.standardizedFileURL
        )
        try ensureNoSymbolicLinks(from: root, through: directory, fileManager: fileManager)
    }

    private static func ensureContained(_ candidate: URL, in root: URL) throws {
        let rootPath = root.standardizedFileURL.path
        let candidatePath = candidate.standardizedFileURL.path
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            throw SottoManagedPathError.outsideRoot(candidate)
        }
    }

    private static func ensureNoSymbolicLinks(
        from root: URL,
        through candidate: URL,
        fileManager: FileManager
    ) throws {
        let root = root.standardizedFileURL
        let candidate = candidate.standardizedFileURL
        try ensureContained(candidate, in: root)

        var current = root
        if isSymbolicLink(current, fileManager: fileManager) {
            throw SottoManagedPathError.symbolicLink(current)
        }
        let relative = candidate.path.dropFirst(root.path.count)
        for component in relative.split(separator: "/") {
            current.appendPathComponent(String(component))
            if isSymbolicLink(current, fileManager: fileManager) {
                throw SottoManagedPathError.symbolicLink(current)
            }
        }
    }

    private static func ensureTreeContainsNoSymbolicLinks(
        at directory: URL,
        fileManager: FileManager
    ) throws {
        for child in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            if isSymbolicLink(child, fileManager: fileManager) {
                throw SottoManagedPathError.symbolicLink(child)
            }
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try ensureTreeContainsNoSymbolicLinks(at: child, fileManager: fileManager)
            }
        }
    }

    private static func isSymbolicLink(_ url: URL, fileManager: FileManager) -> Bool {
        (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
}

public enum DirectorySize {
    public static func bytes(at root: URL, fileManager: FileManager = .default) -> Int64 {
        guard (try? fileManager.destinationOfSymbolicLink(atPath: root.path)) == nil,
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              )
        else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
            ),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true
            else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
