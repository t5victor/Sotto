import Foundation
import XCTest
@testable import SottoCore

final class PersistenceTests: XCTestCase {
    func testJSONStoreRoundTripsPreferences() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("preferences.json")
        let store = JSONFileStore(url: url, defaultValue: SottoPreferences.default)

        var expected = SottoPreferences.default
        expected.language = .spanish
        expected.accent = .coral
        expected.historyLimit = 42
        try await store.save(expected)

        let loaded = await store.load()
        XCTAssertEqual(loaded, expected)
    }

    func testCorruptJSONIsPreservedAndDefaultsAreRecovered() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("preferences.json")
        try Data("not-json".utf8).write(to: url)
        let store = JSONFileStore(url: url, defaultValue: SottoPreferences.default)

        let loaded = await store.load()

        XCTAssertEqual(loaded, .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("preferences.corrupt-") })
    }

    func testHistoryKeepsNewestRecordsWithinLimit() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SottoHistoryRepository(url: root.appendingPathComponent("history.json"))

        for index in 0..<12 {
            let record = TranscriptionRecord(
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                text: "Texto \(index)",
                rawText: "Texto \(index)",
                duration: 1,
                processingTime: 0.1,
                confidence: 0.9,
                targetApplication: nil,
                insertionOutcome: .skipped
            )
            _ = try await repository.add(record, limit: 10)
        }

        let records = await repository.load()
        XCTAssertEqual(records.count, 10)
        XCTAssertEqual(records.first?.text, "Texto 11")
        XCTAssertEqual(records.last?.text, "Texto 2")
    }

    func testVocabularyUpsertUsesSpokenFormAsCaseInsensitiveKey() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SottoVocabularyRepository(
            url: root.appendingPathComponent("vocabulary.json"),
            defaultEntries: []
        )

        _ = try await repository.upsert(
            VocabularyEntry(spokenForm: "Sotto", replacement: "Sotto")
        )
        let entries = try await repository.upsert(
            VocabularyEntry(spokenForm: "sotto", replacement: "SOTTO")
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].replacement, "SOTTO")
    }

    func testStaleRecordingCleanupOnlyDeletesOldCAFRegularFiles() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        let oldRecording = directories.recordings.appendingPathComponent("old.caf")
        let recentRecording = directories.recordings.appendingPathComponent("recent.caf")
        let unrelated = directories.recordings.appendingPathComponent("notes.txt")
        try Data("audio".utf8).write(to: oldRecording)
        try Data("audio".utf8).write(to: recentRecording)
        try Data("keep".utf8).write(to: unrelated)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: oldRecording.path
        )

        let removed = try directories.removeStaleRecordings(olderThan: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldRecording.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentRecording.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoTests-\(UUID().uuidString)", isDirectory: true)
    }
}
