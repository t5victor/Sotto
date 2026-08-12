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

