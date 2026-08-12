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

@MainActor
public final class MicrophoneRecorder {
    public enum RecorderError: LocalizedError {
        case alreadyRecording
        case invalidInputFormat
        case cannotCreateMonoFormat
        case cannotCreateConverter
        case engineStartFailed(Error)
        case writeFailed(Error)
        case notRecording
        case recordingTooShort

        public var errorDescription: String? {
            switch self {
            case .alreadyRecording: "Ya hay una grabación en curso."
            case .invalidInputFormat: "El dispositivo de entrada no ofrece un formato de audio válido."
            case .cannotCreateMonoFormat: "No se pudo preparar el formato mono del micrófono."
            case .cannotCreateConverter: "No se pudo preparar el conversor de audio."
            case .engineStartFailed(let error): "No se pudo iniciar el micrófono: \(error.localizedDescription)"
            case .writeFailed(let error): "No se pudo guardar la grabación: \(error.localizedDescription)"
            case .notRecording: "No hay ninguna grabación activa."
            case .recordingTooShort: "La grabación es demasiado corta. Mantén el atajo mientras hablas."
            }
        }
    }

    public nonisolated let events: AsyncStream<MicrophoneEvent>

    private let continuation: AsyncStream<MicrophoneEvent>.Continuation
    private var engine: AVAudioEngine?
    private var sink: AudioFileSink?
    private var recordingURL: URL?
    private var configurationObserver: NSObjectProtocol?

    public init() {
        let pair = AsyncStream.makeStream(
            of: MicrophoneEvent.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        self.events = pair.stream
        self.continuation = pair.continuation
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        continuation.finish()
    }

    public var isRecording: Bool {
        engine?.isRunning == true && sink != nil
    }

