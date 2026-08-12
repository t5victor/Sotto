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
}
