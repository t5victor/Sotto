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
        expected.hasCompletedOnboarding = true
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

    func testHistorySupportsProjectsAndPinnedRecords() throws {
        let projectID = UUID()
        let record = TranscriptionRecord(
            text: "Texto organizado",
            rawText: "Texto organizado",
            duration: 1,
            processingTime: 0.1,
            confidence: 0.9,
            targetApplication: "Notas",
            insertionOutcome: .inserted,
            projectID: projectID,
            isPinned: true
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)

        XCTAssertEqual(decoded.projectID, projectID)
        XCTAssertTrue(decoded.isPinned)
    }

    func testProjectRepositoryCreatesRenamesAndRemovesProjects() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SottoProjectRepository(url: root.appendingPathComponent("projects.json"))
        let project = SottoProject(name: "Ideas")

        var projects = try await repository.add(project)
        XCTAssertEqual(projects.map(\.name), ["Ideas"])

        projects = try await repository.update(
            id: project.id,
            name: "Ideas de producto",
            icon: "lightbulb",
            accent: .coral
        )
        XCTAssertEqual(projects.first?.name, "Ideas de producto")
        XCTAssertEqual(projects.first?.icon, "lightbulb")
        XCTAssertEqual(projects.first?.accent, .coral)

        projects = try await repository.remove(id: project.id)
        XCTAssertTrue(projects.isEmpty)
    }

    func testHistoryCanMoveAndPinARecord() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SottoHistoryRepository(url: root.appendingPathComponent("history.json"))
        let projectID = UUID()
        let record = TranscriptionRecord(
            text: "Texto",
            rawText: "Texto",
            duration: 1,
            processingTime: 0.1,
            confidence: 0.9,
            targetApplication: nil,
            insertionOutcome: .skipped
        )

        _ = try await repository.add(record, limit: 10)
        _ = try await repository.move(id: record.id, to: projectID)
        let pinned = try await repository.setPinned(id: record.id, isPinned: true)

        XCTAssertEqual(pinned.first?.projectID, projectID)
        XCTAssertTrue(pinned.first?.isPinned == true)
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

    func testVocabularyIdentityMatchesPostProcessorDiacriticRules() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = SottoVocabularyRepository(
            url: root.appendingPathComponent("vocabulary.json"),
            defaultEntries: []
        )

        _ = try await repository.upsert(
            VocabularyEntry(spokenForm: "cafe", replacement: "Cafe")
        )
        let entries = try await repository.upsert(
            VocabularyEntry(spokenForm: "café", replacement: "Café")
        )

        XCTAssertEqual(entries.count, 2)
    }

    func testLegacyPreferencesGainDefaultsWithoutResettingKnownValues() throws {
        let legacy = Data(#"""
        {
          "accent": "coral",
          "language": "es",
          "historyLimit": 42
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(SottoPreferences.self, from: legacy)

        XCTAssertEqual(decoded.accent, .coral)
        XCTAssertEqual(decoded.language, .spanish)
        XCTAssertEqual(decoded.historyLimit, 42)
        XCTAssertEqual(decoded.maximumRecordingDuration, 300)
        XCTAssertTrue(decoded.insertAutomatically)
        XCTAssertFalse(decoded.hasCompletedOnboarding)
    }

    func testInitialOnboardingMigrationDoesNotPreserveTemporaryCompletionFlag() throws {
        let initialMigration = Data(#"""
        {
          "schemaVersion": 3,
          "hasCompletedOnboarding": true
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(SottoPreferences.self, from: initialMigration)

        XCTAssertFalse(decoded.hasCompletedOnboarding)
    }

    func testLegacyHistoryRecordMigratesMissingMetadata() throws {
        let legacy = Data(#"""
        {
          "text": "Texto conservado"
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: legacy)

        XCTAssertEqual(decoded.text, "Texto conservado")
        XCTAssertEqual(decoded.rawText, "Texto conservado")
        XCTAssertEqual(decoded.duration, 0)
        XCTAssertEqual(decoded.insertionOutcome, .skipped)
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

    func testPrepareRejectsSymbolicLinkInManagedDirectoryChain() throws {
        let root = temporaryDirectory()
        let external = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let directories = SottoDirectories(root: root)
        try FileManager.default.createSymbolicLink(
            at: directories.state,
            withDestinationURL: external
        )

        XCTAssertThrowsError(try directories.prepare()) { error in
            guard case SottoManagedPathError.symbolicLink(let url) = error else {
                return XCTFail("Expected symbolicLink, got \(error)")
            }
            XCTAssertEqual(url, directories.state)
        }
    }

    func testManagedJSONStoreRefusesReplacedParentSymlink() async throws {
        let root = temporaryDirectory()
        let external = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: directories.state)
        try FileManager.default.createSymbolicLink(
            at: directories.state,
            withDestinationURL: external
        )
        let store = JSONFileStore(
            url: directories.preferencesFile,
            defaultValue: SottoPreferences.default,
            managedRoot: directories.root,
            managedDirectory: directories.state
        )

        do {
            try await store.save(.default)
            XCTFail("Expected symbolic-link rejection")
        } catch SottoManagedPathError.symbolicLink(let url) {
            XCTAssertEqual(url.standardizedFileURL.path, directories.state.standardizedFileURL.path)
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: external.appendingPathComponent("preferences.json").path
            )
        )
    }

    func testRecordingCleanupRefusesReplacedParentSymlink() throws {
        let root = temporaryDirectory()
        let external = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let marker = external.appendingPathComponent("old.caf")
        try Data("outside".utf8).write(to: marker)
        try FileManager.default.removeItem(at: directories.recordings)
        try FileManager.default.createSymbolicLink(
            at: directories.recordings,
            withDestinationURL: external
        )

        XCTAssertThrowsError(
            try directories.removeStaleRecordings(olderThan: .distantFuture)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoTests-\(UUID().uuidString)", isDirectory: true)
    }
}
