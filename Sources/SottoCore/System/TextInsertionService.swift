import AppKit
import ApplicationServices
import Foundation

public struct InsertionTargetInfo: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let applicationName: String?
    public let bundleIdentifier: String?
    public let launchDate: Date?
    public let executableURL: URL?

    public init(
        processIdentifier: pid_t,
        applicationName: String?,
        bundleIdentifier: String?,
        launchDate: Date? = nil,
        executableURL: URL? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.launchDate = launchDate
        self.executableURL = executableURL?.standardizedFileURL.resolvingSymlinksInPath()
    }

    public func matches(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        launchDate: Date?,
        executableURL: URL?
    ) -> Bool {
        guard self.processIdentifier == processIdentifier,
              self.bundleIdentifier == bundleIdentifier
        else { return false }

        if let expectedLaunchDate = self.launchDate {
            guard let launchDate,
                  abs(expectedLaunchDate.timeIntervalSince(launchDate)) < 0.001
            else { return false }
        }
        if let expectedExecutableURL = self.executableURL {
            guard executableURL?.standardizedFileURL.resolvingSymlinksInPath()
                    == expectedExecutableURL
            else { return false }
        }
        return true
    }
}

@MainActor
public final class TextInsertionService {
    private var target: InsertionTargetInfo?

    public init() {}

    @discardableResult
    public func captureTarget(
        excludingBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> InsertionTargetInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != excludingBundleIdentifier
        else {
            target = nil
            return nil
        }

        let target = InsertionTargetInfo(
            processIdentifier: app.processIdentifier,
            applicationName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            launchDate: app.launchDate,
            executableURL: app.executableURL
        )
        self.target = target
        return target
    }

    public func clearTarget() {
        target = nil
    }

    public func isTargetValid(_ target: InsertionTargetInfo) -> Bool {
        validatedApplication(for: target) != nil
    }

    public func insert(_ text: String, automatically: Bool) async -> TextInsertionOutcome {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .skipped }
        defer { target = nil }

        if !automatically {
            writeToPasteboard(value)
            return .copied
        }

        let trusted = SottoPermissionService.accessibilityStatus().isGranted
        if trusted,
           let target,
           validatedApplication(for: target) != nil,
           insertViaAccessibility(value, target: target) {
            return .inserted
        }

        if trusted,
           let target,
           validatedApplication(for: target) != nil,
           await pasteUsingKeyboard(value, target: target) {
            // macOS does not expose an API that confirms a synthetic Command-V
            // changed the destination. Persist the honest attempted outcome.
            return .pasteAttempted
        }

        writeToPasteboard(value)
        return .copied
    }

    private func validatedApplication(
        for target: InsertionTargetInfo
    ) -> NSRunningApplication? {
        guard let application = NSRunningApplication(
            processIdentifier: target.processIdentifier
        ),
              !application.isTerminated,
              target.matches(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier,
                launchDate: application.launchDate,
                executableURL: application.executableURL
              )
        else { return nil }
        return application
    }

    private func insertViaAccessibility(
        _ text: String,
        target: InsertionTargetInfo
    ) -> Bool {
        guard validatedApplication(for: target) != nil else { return false }
        let application = AXUIElementCreateApplication(target.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedValue else { return false }
        let focused = focusedValue as! AXUIElement

        var settable = DarwinBoolean(false)
        let check = AXUIElementIsAttributeSettable(
            focused,
            kAXSelectedTextAttribute as CFString,
            &settable
        )
        guard check == .success, settable.boolValue,
              validatedApplication(for: target) != nil
        else { return false }

        let result = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    private func pasteUsingKeyboard(
        _ text: String,
        target: InsertionTargetInfo
    ) async -> Bool {
        guard let application = validatedApplication(for: target),
              let snapshot = PasteboardSnapshot.captureIfSafe()
        else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore()
            return false
        }
        let sottoChangeCount = pasteboard.changeCount
        defer {
            if pasteboard.changeCount == sottoChangeCount {
                snapshot.restore()
            }
        }

        application.activate(options: [])
        try? await Task.sleep(for: .milliseconds(80))

        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              target.matches(
                processIdentifier: frontmost.processIdentifier,
                bundleIdentifier: frontmost.bundleIdentifier,
                launchDate: frontmost.launchDate,
                executableURL: frontmost.executableURL
              )
        else { return false }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: false
              )
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(500))
        return validatedApplication(for: target) != nil
    }

    private func writeToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

@MainActor
private struct PasteboardSnapshot {
    /// There is no public size metadata for pasteboard values. Even reading a
    /// string to enforce a post-hoc byte limit can materialize an arbitrarily
    /// large lazy value on the main actor, so synthetic paste is permitted only
    /// when there is nothing to snapshot.
    static func captureIfSafe() -> PasteboardSnapshot? {
        let items = NSPasteboard.general.pasteboardItems ?? []
        return items.isEmpty ? PasteboardSnapshot() : nil
    }

    func restore() {
        NSPasteboard.general.clearContents()
    }
}
