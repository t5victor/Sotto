import Foundation

public actor SottoHistoryRepository {
    private let store: JSONFileStore<[TranscriptionRecord]>

    public init(url: URL) {
        self.store = JSONFileStore(url: url, defaultValue: [])
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

    public func clear() async throws {
        try await store.save([])
    }
}
