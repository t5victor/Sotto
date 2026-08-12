import Carbon.HIToolbox
import Foundation

private final class HotKeyCallbackBox: @unchecked Sendable {
    let handler: @Sendable (UInt32) -> Void

    init(handler: @escaping @Sendable (UInt32) -> Void) {
        self.handler = handler
    }
}

private func sottoHotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let box = Unmanaged<HotKeyCallbackBox>.fromOpaque(userData).takeUnretainedValue()
    box.handler(GetEventKind(event))
    return noErr
}

@MainActor
public final class GlobalHotKeyMonitor {
    public enum HotKeyError: LocalizedError {
        case eventHandler(OSStatus)
        case registration(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .eventHandler(let status):
                "No se pudo preparar el atajo global (código \(status))."
            case .registration(let status):
                "El atajo está ocupado por otra aplicación (código \(status))."
            }
        }
    }

    public var onPressed: (() -> Void)?
    public var onReleased: (() -> Void)?

    nonisolated(unsafe) private var eventHandler: EventHandlerRef?
    nonisolated(unsafe) private var hotKey: EventHotKeyRef?
    private var callbackBox: HotKeyCallbackBox?

    public init() {}

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    public func register(_ shortcut: SottoShortcut) throws {
        unregisterHotKey()
        if eventHandler == nil {
            try installEventHandler()
        }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x534F_5454, id: 1) // SOTT
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw HotKeyError.registration(status)
        }
        hotKey = reference
    }

    public func unregisterHotKey() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func installEventHandler() throws {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            ),
        ]

        let forwardingBox = HotKeyCallbackBox { [weak self] kind in
            Task { @MainActor in
                guard let self else { return }
                if kind == UInt32(kEventHotKeyPressed) {
                    self.onPressed?()
                } else if kind == UInt32(kEventHotKeyReleased) {
                    self.onReleased?()
                }
            }
        }

        callbackBox = forwardingBox
        let opaque = Unmanaged.passUnretained(forwardingBox).toOpaque()
        var reference: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            sottoHotKeyEventCallback,
            eventTypes.count,
            &eventTypes,
            opaque,
            &reference
        )
        guard status == noErr, let reference else {
            callbackBox = nil
            throw HotKeyError.eventHandler(status)
        }
        eventHandler = reference
    }
}
