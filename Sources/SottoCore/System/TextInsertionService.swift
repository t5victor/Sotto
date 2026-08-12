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

    private func insertViaAccessibility(_ text: String, target: InsertionTargetInfo) -> Bool {
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
        guard check == .success, settable.boolValue else { return false }

        let result = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    private func pasteUsingKeyboard(_ text: String, target: InsertionTargetInfo) async -> Bool {
        guard let application = NSRunningApplication(processIdentifier: target.processIdentifier) else {
            return false
        }

        let snapshot = PasteboardSnapshot.capture()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        let sottoChangeCount = pasteboard.changeCount

        application.activate(options: [])
        try? await Task.sleep(for: .milliseconds(80))

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                == target.processIdentifier
        else {
            snapshot.restore()
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(500))
        if pasteboard.changeCount == sottoChangeCount {
            snapshot.restore()
        }
        return true
    }

    private func writeToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

@MainActor
private struct PasteboardSnapshot {
    struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [Item]

    static func capture() -> PasteboardSnapshot {
        let values = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            Item(values: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return PasteboardSnapshot(items: values)
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restoredItems = items.map { snapshot -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
