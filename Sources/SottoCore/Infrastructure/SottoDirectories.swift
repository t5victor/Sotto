import Foundation

public struct SottoDirectories: Sendable {
    public let root: URL
    public let models: URL
    public let recordings: URL
    public let state: URL
    public let logs: URL

    public init(root: URL) {
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

    public func prepare() throws {
        for directory in [root, models, recordings, state, logs] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
    }

    public func newRecordingURL(id: UUID = UUID()) -> URL {
        recordings.appendingPathComponent("\(id.uuidString).caf")
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

        let files = try fileManager.contentsOfDirectory(
            at: recordings,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var removed = 0
        for file in files where file.pathExtension.lowercased() == "caf" {
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
}

public enum DirectorySize {
    public static func bytes(at root: URL, fileManager: FileManager = .default) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true
            else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
