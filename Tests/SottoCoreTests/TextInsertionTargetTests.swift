import Foundation
import SottoLocalization
import XCTest
@testable import SottoCore

final class TextInsertionTargetTests: XCTestCase {
    func testTargetIdentityRequiresBundleLaunchAndExecutableToMatch() {
        let launchDate = Date(timeIntervalSince1970: 1_723_456_789)
        let executable = URL(fileURLWithPath: "/Applications/Notes.app/Contents/MacOS/Notes")
        let target = InsertionTargetInfo(
            processIdentifier: 42,
            applicationName: "Notas",
            bundleIdentifier: "com.apple.Notes",
            launchDate: launchDate,
            executableURL: executable
        )

        XCTAssertTrue(
            target.matches(
                processIdentifier: 42,
                bundleIdentifier: "com.apple.Notes",
                launchDate: launchDate,
                executableURL: executable
            )
        )
        XCTAssertFalse(
            target.matches(
                processIdentifier: 42,
                bundleIdentifier: "com.example.reused-pid",
                launchDate: launchDate,
                executableURL: executable
            )
        )
        XCTAssertFalse(
            target.matches(
                processIdentifier: 42,
                bundleIdentifier: "com.apple.Notes",
                launchDate: launchDate.addingTimeInterval(1),
                executableURL: executable
            )
        )
        XCTAssertFalse(
            target.matches(
                processIdentifier: 42,
                bundleIdentifier: "com.apple.Notes",
                launchDate: launchDate,
                executableURL: URL(fileURLWithPath: "/tmp/fake")
            )
        )
    }

    func testPasteAttemptIsDistinctFromVerifiedInsertionAndLegacyPaste() {
        XCTAssertEqual(
            TextInsertionOutcome.pasteAttempted.displayName,
            SottoLocalization.string("outcome.paste_attempted")
        )
        XCTAssertNotEqual(TextInsertionOutcome.pasteAttempted, .inserted)
        XCTAssertNotEqual(TextInsertionOutcome.pasteAttempted, .pasted)
    }
}
