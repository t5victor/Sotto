@preconcurrency import AVFoundation
import Foundation

public struct RecordedAudio: Equatable, Sendable {
    public let url: URL
    public let duration: TimeInterval
    public let frameCount: Int64
    public let peakLevel: Double

    public init(url: URL, duration: TimeInterval, frameCount: Int64, peakLevel: Double) {
        self.url = url
        self.duration = duration
        self.frameCount = frameCount
        self.peakLevel = peakLevel
    }
}

public enum MicrophoneEvent: Sendable {
    case level(Double)
    case failure(String)
}
