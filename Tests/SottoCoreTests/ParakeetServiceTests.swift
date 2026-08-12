import Foundation
import XCTest
@testable import SottoCore

final class ParakeetServiceTests: XCTestCase {
    func testInspectionOfEmptyModelDirectoryDoesNotUseTheNetwork() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoParakeetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        let service = ParakeetService(directories: directories)

        let state = await service.inspect()

        #if arch(arm64)
        XCTAssertEqual(state, .notInstalled)
        #else
        guard case .failed = state else {
            return XCTFail("Non-Apple-Silicon hosts should report unsupported hardware")
        }
        #endif
    }

    func testModelDeletionIsLimitedToTheExpectedChildDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoParakeetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        let expectedMarker = directories.parakeetV3.appendingPathComponent("partial-download")
        let sibling = directories.models.appendingPathComponent("keep-me", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directories.parakeetV3,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: expectedMarker)

        let service = ParakeetService(directories: directories)
        try await service.deleteModel()
        let state = await service.currentState()

        XCTAssertFalse(FileManager.default.fileExists(atPath: directories.parakeetV3.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
        XCTAssertEqual(state, .notInstalled)
    }

    func testModelDeletionRefusesSymbolicLinkTarget() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoParakeetTests-\(UUID().uuidString)", isDirectory: true)
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoExternalModel-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let marker = external.appendingPathComponent("must-survive")
        try Data("outside".utf8).write(to: marker)
        try FileManager.default.createSymbolicLink(
            at: directories.parakeetV3,
            withDestinationURL: external
        )
        let service = ParakeetService(directories: directories)

        do {
            try await service.deleteModel()
            XCTFail("Expected symbolic-link rejection")
        } catch SottoManagedPathError.symbolicLink(let url) {
            XCTAssertEqual(url, directories.parakeetV3)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }

    func testUnreadableAudioIsRejectedBeforeModelPreparation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SottoParakeetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directories = SottoDirectories(root: root)
        try directories.prepare()
        let service = ParakeetService(directories: directories)
        let missing = root.appendingPathComponent("missing.caf")

        do {
            _ = try await service.transcribe(audioURL: missing, language: .spanish)
            XCTFail("Expected unreadable audio")
        } catch ParakeetService.ServiceError.unreadableAudio(let url) {
            XCTAssertEqual(url, missing)
        }
    }
}
