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

    public func start(writingTo url: URL) throws {
        guard !isRecording else { throw RecorderError.alreadyRecording }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.invalidInputFormat
        }
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.cannotCreateMonoFormat
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: monoFormat) else {
            throw RecorderError.cannotCreateConverter
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: monoFormat.settings,
            commonFormat: monoFormat.commonFormat,
            interleaved: monoFormat.isInterleaved
        )
        let sink = AudioFileSink(
            file: file,
            converter: converter,
            format: monoFormat,
            eventHandler: { [continuation] event in
                continuation.yield(event)
            }
        )

        installSottoAudioTap(on: input, format: inputFormat, sink: sink)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineStartFailed(error)
        }

        self.engine = engine
        self.sink = sink
        self.recordingURL = url
        installConfigurationObserver(for: engine)
    }

    public func stop() throws -> RecordedAudio {
        guard let engine, let sink, let recordingURL else {
            throw RecorderError.notRecording
        }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        removeConfigurationObserver()
        let snapshot = sink.finish()

        self.engine = nil
        self.sink = nil
        self.recordingURL = nil

        if let error = snapshot.error {
            throw RecorderError.writeFailed(error)
        }
        let duration = Double(snapshot.frames) / snapshot.sampleRate
        guard duration >= 0.18 else {
            try? FileManager.default.removeItem(at: recordingURL)
            throw RecorderError.recordingTooShort
        }

        return RecordedAudio(
            url: recordingURL,
            duration: duration,
            frameCount: snapshot.frames,
            peakLevel: snapshot.peak
        )
    }

