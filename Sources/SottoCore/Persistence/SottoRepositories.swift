import Foundation
import SottoLocalization

public actor SottoHistoryRepository {
    private let store: JSONFileStore<[TranscriptionRecord]>

    public init(
        url: URL,
        managedRoot: URL? = nil,
        managedDirectory: URL? = nil
    ) {
        self.store = JSONFileStore(
            url: url,
            defaultValue: [],
            managedRoot: managedRoot,
            managedDirectory: managedDirectory
        )
    }

    public func load() async -> [TranscriptionRecord] {
        await store.load().sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func add(_ record: TranscriptionRecord, limit: Int) async throws -> [TranscriptionRecord] {
        var records = await load()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        records = Array(records.prefix(min(max(limit, 10), 1_000)))
        try await store.save(records)
        return records
    }

    @discardableResult
    public func remove(id: UUID) async throws -> [TranscriptionRecord] {
        var records = await load()
        records.removeAll { $0.id == id }
        try await store.save(records)
        return records
    }

    @discardableResult
    public func move(id: UUID, to projectID: UUID?) async throws -> [TranscriptionRecord] {
        var records = await load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return records }
        records[index].projectID = projectID
        try await store.save(records)
        return records
    }

    @discardableResult
    public func moveAll(from projectID: UUID, to destinationProjectID: UUID?) async throws -> [TranscriptionRecord] {
        var records = await load()
        for index in records.indices where records[index].projectID == projectID {
            records[index].projectID = destinationProjectID
        }
        try await store.save(records)
        return records
    }

    @discardableResult
    public func setPinned(id: UUID, isPinned: Bool) async throws -> [TranscriptionRecord] {
        var records = await load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return records }
        records[index].isPinned = isPinned
        try await store.save(records)
        return records
    }

    public func clear() async throws {
        try await store.save([])
    }
}

public actor SottoProjectRepository {
    public enum ProjectError: LocalizedError {
        case emptyName

        public var errorDescription: String? {
            switch self {
            case .emptyName: SottoLocalization.string("error.project.empty_name")
            }
        }
    }

    private let store: JSONFileStore<[SottoProject]>

    public init(
        url: URL,
        managedRoot: URL? = nil,
        managedDirectory: URL? = nil
    ) {
        self.store = JSONFileStore(
            url: url,
            defaultValue: [],
            managedRoot: managedRoot,
            managedDirectory: managedDirectory
        )
    }

    public func load() async -> [SottoProject] {
        await store.load().sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func add(_ project: SottoProject) async throws -> [SottoProject] {
        let name = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProjectError.emptyName }

        var projects = await load()
        projects.removeAll { $0.id == project.id }
        projects.insert(
            SottoProject(
                id: project.id,
                name: name,
                icon: project.icon,
                accent: project.accent,
                createdAt: project.createdAt
            ),
            at: 0
        )
        try await store.save(projects)
        return projects
    }

    @discardableResult
    public func update(
        id: UUID,
        name: String,
        icon: String,
        accent: SottoAccent
    ) async throws -> [SottoProject] {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProjectError.emptyName }

        var projects = await load()
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return projects }
        let existing = projects[index]
        projects[index] = SottoProject(
            id: existing.id,
            name: name,
            icon: icon,
            accent: accent,
            createdAt: existing.createdAt
        )
        try await store.save(projects)
        return projects
    }

    @discardableResult
    public func remove(id: UUID) async throws -> [SottoProject] {
        var projects = await load()
        projects.removeAll { $0.id == id }
        try await store.save(projects)
        return projects
    }
}

public actor SottoVocabularyRepository {
    public enum VocabularyError: LocalizedError {
        case emptySpokenForm
        case emptyReplacement

        public var errorDescription: String? {
            switch self {
            case .emptySpokenForm: SottoLocalization.string("error.vocabulary.empty_spoken_form")
            case .emptyReplacement: SottoLocalization.string("error.vocabulary.empty_replacement")
            }
        }
    }

    private let store: JSONFileStore<[VocabularyEntry]>

    public init(
        url: URL,
        defaultEntries: [VocabularyEntry] = [.sotto],
        managedRoot: URL? = nil,
        managedDirectory: URL? = nil
    ) {
        self.store = JSONFileStore(
            url: url,
            defaultValue: defaultEntries,
            managedRoot: managedRoot,
            managedDirectory: managedDirectory
        )
    }

    public func load() async -> [VocabularyEntry] {
        await store.load().sorted {
            $0.spokenForm.localizedCaseInsensitiveCompare($1.spokenForm) == .orderedAscending
        }
    }

    @discardableResult
    public func upsert(_ entry: VocabularyEntry) async throws -> [VocabularyEntry] {
        let spoken = entry.spokenForm.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = entry.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { throw VocabularyError.emptySpokenForm }
        guard !replacement.isEmpty else { throw VocabularyError.emptyReplacement }

        var entries = await load()
        let normalized = spoken.folding(options: [.caseInsensitive], locale: .current)
        if let index = entries.firstIndex(where: {
            $0.spokenForm.folding(options: [.caseInsensitive], locale: .current)
                == normalized
        }) {
            entries[index] = VocabularyEntry(
                id: entries[index].id,
                spokenForm: spoken,
                replacement: replacement
            )
        } else {
            entries.append(VocabularyEntry(id: entry.id, spokenForm: spoken, replacement: replacement))
        }
        entries.sort {
            $0.spokenForm.localizedCaseInsensitiveCompare($1.spokenForm) == .orderedAscending
        }
        try await store.save(entries)
        return entries
    }

    @discardableResult
    public func remove(id: UUID) async throws -> [VocabularyEntry] {
        var entries = await load()
        entries.removeAll { $0.id == id }
        try await store.save(entries)
        return entries
    }
}
