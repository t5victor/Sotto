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

    public func cancel() {
        guard let engine else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        removeConfigurationObserver()
        _ = sink?.finish()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        self.engine = nil
        self.sink = nil
        self.recordingURL = nil
    }

    private func installConfigurationObserver(for engine: AVAudioEngine) {
        removeConfigurationObserver()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [continuation] _ in
            continuation.yield(
                .failure("El dispositivo de audio cambió durante la grabación. Vuelve a intentarlo.")
            )
        }
    }

    private func removeConfigurationObserver() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
    }
}

/// AVAudioEngine invokes its tap on a realtime audio queue. Keeping the tap
/// closure outside `MicrophoneRecorder`'s MainActor isolation prevents Swift 6
/// executor checks from trapping on that queue; `AudioFileSink` owns its own
/// lock and is designed for this callback.
private func installSottoAudioTap(
    on input: AVAudioInputNode,
    format: AVAudioFormat,
    sink: AudioFileSink
) {
    input.installTap(onBus: 0, bufferSize: 2_048, format: format) { buffer, _ in
        sink.consume(buffer)
    }
}

private final class AudioFileSink: @unchecked Sendable {
    struct Snapshot {
        let frames: Int64
        let sampleRate: Double
        let peak: Double
        let error: Error?
    }

    private let lock = NSLock()
    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let eventHandler: @Sendable (MicrophoneEvent) -> Void
    private var frames: Int64 = 0
    private var peak: Double = 0
    private var firstError: Error?
    private var finished = false

    init(
        file: AVAudioFile,
        converter: AVAudioConverter,
        format: AVAudioFormat,
        eventHandler: @escaping @Sendable (MicrophoneEvent) -> Void
    ) {
        self.file = file
        self.converter = converter
        self.format = format
        self.eventHandler = eventHandler
    }

    func consume(_ input: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, firstError == nil else { return }

        guard let mono = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: max(input.frameCapacity, input.frameLength)
        ) else { return }

        do {
            try converter.convert(to: mono, from: input)
            try file.write(from: mono)
            frames += Int64(mono.frameLength)

            let level = Self.normalizedPeak(in: mono)
            peak = max(peak, level)
            eventHandler(.level(level))
        } catch {
            firstError = error
            eventHandler(.failure(error.localizedDescription))
        }
    }

    func finish() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        finished = true
        return Snapshot(
            frames: frames,
            sampleRate: format.sampleRate,
            peak: peak,
            error: firstError
        )
    }

    private static func normalizedPeak(in buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var value: Float = 0
        for index in 0..<count {
            value = max(value, abs(channel[index]))
        }

        // A logarithmic response makes quiet speech visible without pinning
        // normal speech at 100 percent.
        let decibels = 20 * log10(max(value, 0.000_01))
        return min(max(Double((decibels + 55) / 55), 0), 1)
    }
}
