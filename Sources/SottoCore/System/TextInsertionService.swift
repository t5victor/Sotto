import AppKit
import ApplicationServices
import Foundation

public struct InsertionTargetInfo: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let applicationName: String?
    public let bundleIdentifier: String?

    public init(
        processIdentifier: pid_t,
        applicationName: String?,
        bundleIdentifier: String?
    ) {
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
    }
}

@MainActor
public final class TextInsertionService {
    private var target: InsertionTargetInfo?

    public init() {}

    @discardableResult
    public func captureTarget(excludingBundleIdentifier: String? = Bundle.main.bundleIdentifier) -> InsertionTargetInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != excludingBundleIdentifier
        else {
            target = nil
            return nil
        }

        let target = InsertionTargetInfo(
            processIdentifier: app.processIdentifier,
            applicationName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier
        )
        self.target = target
        return target
    }

    public func clearTarget() {
        target = nil
    }

    public func insert(_ text: String, automatically: Bool) async -> TextInsertionOutcome {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .skipped }

        if !automatically {
            writeToPasteboard(value)
            return .copied
        }

        let trusted = SottoPermissionService.accessibilityStatus().isGranted
        if trusted, let target, insertViaAccessibility(value, target: target) {
            self.target = nil
            return .inserted
        }

        if trusted, let target, await pasteUsingKeyboard(value, target: target) {
            self.target = nil
            return .pasted
        }

        writeToPasteboard(value)
        self.target = nil
        return .copied
    }

