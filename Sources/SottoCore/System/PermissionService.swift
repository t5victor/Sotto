@preconcurrency import AVFoundation
import ApplicationServices
import Foundation

public enum SottoPermissionService {
    public static func microphoneStatus() -> SottoPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    public static func requestMicrophone() async -> SottoPermissionStatus {
        if microphoneStatus() != .notDetermined {
            return microphoneStatus()
        }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .granted : .denied
    }

    public static func accessibilityStatus(prompt: Bool = false) -> SottoPermissionStatus {
        if prompt {
            // The imported global is not annotated for Swift 6 concurrency.
            // Its documented CFString value is stable and avoids reading that
            // mutable C global from arbitrary executors.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
        }
        return AXIsProcessTrusted() ? .granted : .denied
    }
}
