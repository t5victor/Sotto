@preconcurrency import AVFoundation
import Darwin
import Foundation
import SottoAudioRingC
import SottoLocalization

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
    case limitReached
    case failure(String)
}

@MainActor
public final class MicrophoneRecorder {
    public enum RecorderError: LocalizedError {
        case alreadyRecording
        case invalidInputFormat
        case cannotCreateMonoFormat
        case cannotCreateConverter
        case cannotCreateBufferQueue
        case unsafeDestination(URL)
        case engineStartFailed(Error)
        case writeFailed(Error)
        case notRecording
        case recordingTooShort

        public var errorDescription: String? {
            switch self {
            case .alreadyRecording: SottoLocalization.string("error.microphone.already_recording")
            case .invalidInputFormat: SottoLocalization.string("error.microphone.invalid_input_format")
            case .cannotCreateMonoFormat: SottoLocalization.string("error.microphone.mono_format")
            case .cannotCreateConverter: SottoLocalization.string("error.microphone.converter")
            case .cannotCreateBufferQueue: SottoLocalization.string("error.microphone.buffer_queue")
            case .unsafeDestination(let url):
                SottoLocalization.format("error.microphone.unsafe_destination", url.path)
            case .engineStartFailed(let error):
                SottoLocalization.format("error.microphone.engine_start", error.localizedDescription)
            case .writeFailed(let error):
                SottoLocalization.format("error.microphone.write", error.localizedDescription)
            case .notRecording: SottoLocalization.string("error.microphone.not_recording")
            case .recordingTooShort: SottoLocalization.string("error.microphone.recording_too_short")
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

    public func start(
        writingTo url: URL,
        maximumDuration: TimeInterval = 300
    ) throws {
        guard !isRecording else { throw RecorderError.alreadyRecording }
        let parent = url.deletingLastPathComponent()
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: parent.path)) == nil,
              (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) == nil
        else {
            throw RecorderError.unsafeDestination(url)
        }

        try FileManager.default.createDirectory(
            at: parent,
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
        let realtimeFrameCapacity = Self.realtimeFrameCapacity(
            sampleRate: inputFormat.sampleRate
        )
        guard let sink = AudioFileSink(
            file: file,
            converter: converter,
            inputFormat: inputFormat,
            outputFormat: monoFormat,
            inputCapacity: realtimeFrameCapacity,
            maximumDuration: min(max(maximumDuration, 30), 1_800),
            eventHandler: { [continuation] event in
                continuation.yield(event)
            }
        ) else {
            try? FileManager.default.removeItem(at: url)
            throw RecorderError.cannotCreateBufferQueue
        }

        installSottoAudioTap(on: input, format: inputFormat, sink: sink)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            _ = sink.finish()
            try? FileManager.default.removeItem(at: url)
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
            try? FileManager.default.removeItem(at: recordingURL)
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
                .failure(SottoLocalization.string("error.microphone.configuration_changed"))
            )
        }
    }

    private func removeConfigurationObserver() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
    }

    /// Core Audio can deliver a hardware quantum larger than the tap's
    /// requested buffer size (4,800 frames was observed at 48 kHz). Reserve a
    /// quarter second, with practical lower/upper bounds, before starting.
    nonisolated static func realtimeFrameCapacity(
        sampleRate: Double
    ) -> AVAudioFrameCount {
        let quarterSecond = ceil(max(sampleRate, 1) * 0.25)
        return AVAudioFrameCount(min(max(quarterSecond, 16_384), 65_536))
    }
}

/// AVAudioEngine invokes its tap on a realtime audio queue. The callback does
/// only a bounded memcpy into a preallocated slot, guarded by a non-blocking
/// try-lock, and signals the worker. Conversion, file I/O, metering,
/// allocation and AsyncStream delivery all happen on the worker queue.
private func installSottoAudioTap(
    on input: AVAudioInputNode,
    format: AVAudioFormat,
    sink: AudioFileSink
) {
    input.installTap(onBus: 0, bufferSize: 2_048, format: format) { buffer, _ in
        sink.enqueueFromRealtimeThread(buffer)
    }
}

private enum AudioSinkError: LocalizedError {
    case realtimeQueueOverflow
    case incompatibleBuffer

    var errorDescription: String? {
        switch self {
        case .realtimeQueueOverflow:
            SottoLocalization.string("error.audio.realtime_queue_overflow")
        case .incompatibleBuffer:
            SottoLocalization.string("error.audio.incompatible_buffer")
        }
    }
}

private final class AudioFileSink: @unchecked Sendable {
    struct Snapshot {
        let frames: Int64
        let sampleRate: Double
        let peak: Double
        let error: Error?
    }

    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let maximumFrames: Int64
    private let eventHandler: @Sendable (MicrophoneEvent) -> Void
    private let ring: PreallocatedAudioRing
    private let workerQueue = DispatchQueue(
        label: "com.sotto.audio-file-writer",
        qos: .userInitiated
    )
    private let workerFinished = DispatchSemaphore(value: 0)
    private let finishLock = NSLock()

    private var frames: Int64 = 0
    private var peak: Double = 0
    private var firstError: Error?
    private var didReportLimit = false
    private var didFinish = false
    private var finalSnapshot: Snapshot?

    init?(
        file: AVAudioFile,
        converter: AVAudioConverter,
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        inputCapacity: AVAudioFrameCount,
        maximumDuration: TimeInterval,
        eventHandler: @escaping @Sendable (MicrophoneEvent) -> Void
    ) {
        guard let ring = PreallocatedAudioRing(
            format: inputFormat,
            frameCapacity: inputCapacity,
            slotCount: 32
        ) else { return nil }
        self.file = file
        self.converter = converter
        self.outputFormat = outputFormat
        self.maximumFrames = max(1, Int64(maximumDuration * outputFormat.sampleRate))
        self.eventHandler = eventHandler
        self.ring = ring

        workerQueue.async { [self] in
            runWorker(inputCapacity: inputCapacity, inputSampleRate: inputFormat.sampleRate)
        }
    }

    func enqueueFromRealtimeThread(_ input: AVAudioPCMBuffer) {
        ring.enqueueFromRealtimeThread(input)
    }

    func finish() -> Snapshot {
        finishLock.lock()
        defer { finishLock.unlock() }
        if let finalSnapshot {
            return finalSnapshot
        }
        if !didFinish {
            didFinish = true
            ring.close()
            workerFinished.wait()
        }
        let snapshot = Snapshot(
            frames: frames,
            sampleRate: outputFormat.sampleRate,
            peak: peak,
            error: firstError
        )
        finalSnapshot = snapshot
        return snapshot
    }

    private func runWorker(
        inputCapacity: AVAudioFrameCount,
        inputSampleRate: Double
    ) {
        defer { workerFinished.signal() }
        let ratio = outputFormat.sampleRate / inputSampleRate
        let outputCapacity = AVAudioFrameCount(
            ceil(Double(inputCapacity) * ratio) + 64
        )
        guard let mono = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputCapacity
        ) else {
            recordFailure(AudioSinkError.incompatibleBuffer)
            return
        }

        while let input = ring.waitForNextBuffer() {
            process(input, output: mono)
            ring.completeCurrentBuffer()

            if ring.didOverflow {
                recordFailure(AudioSinkError.realtimeQueueOverflow)
                ring.close()
            }
        }
        if ring.didOverflow {
            recordFailure(AudioSinkError.realtimeQueueOverflow)
        }
    }

    private func process(
        _ input: AVAudioPCMBuffer,
        output mono: AVAudioPCMBuffer
    ) {
        guard firstError == nil, frames < maximumFrames else { return }

        do {
            mono.frameLength = 0
            try converter.convert(to: mono, from: input)
            let remaining = maximumFrames - frames
            if Int64(mono.frameLength) > remaining {
                mono.frameLength = AVAudioFrameCount(remaining)
            }
            guard mono.frameLength > 0 else { return }

            try file.write(from: mono)
            frames += Int64(mono.frameLength)
            let level = Self.normalizedPeak(in: mono)
            peak = max(peak, level)
            eventHandler(.level(level))

            if frames >= maximumFrames, !didReportLimit {
                didReportLimit = true
                ring.close()
                eventHandler(.limitReached)
            }
        } catch {
            recordFailure(error)
            ring.close()
        }
    }

    private func recordFailure(_ error: Error) {
        guard firstError == nil else { return }
        firstError = error
        eventHandler(.failure(error.localizedDescription))
    }

    private static func normalizedPeak(in buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var value: Float = 0
        for index in 0..<count {
            value = max(value, abs(channel[index]))
        }

        let decibels = 20 * log10(max(value, 0.000_01))
        return min(max(Double((decibels + 55) / 55), 0), 1)
    }
}

/// Single-producer/single-consumer storage whose memory is allocated before
/// the audio engine starts. The producer never waits for the consumer.
private final class PreallocatedAudioRing: @unchecked Sendable {
    private let available = DispatchSemaphore(value: 0)
    private let slots: [AVAudioPCMBuffer]
    private let frameCapacity: AVAudioFrameCount
    private let state: OpaquePointer

    init?(
        format: AVAudioFormat,
        frameCapacity: AVAudioFrameCount,
        slotCount: Int
    ) {
        var buffers: [AVAudioPCMBuffer] = []
        buffers.reserveCapacity(slotCount)
        for _ in 0..<slotCount {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCapacity
            ) else { return nil }
            buffers.append(buffer)
        }
        guard let state = sotto_audio_ring_create(UInt32(slotCount)) else {
            return nil
        }
        self.slots = buffers
        self.frameCapacity = frameCapacity
        self.state = state
    }

    deinit {
        sotto_audio_ring_destroy(state)
    }

    var didOverflow: Bool {
        sotto_audio_ring_did_overflow(state)
    }

    /// Called only by Core Audio's realtime callback.
    func enqueueFromRealtimeThread(_ source: AVAudioPCMBuffer) {
        guard source.frameLength <= frameCapacity else {
            sotto_audio_ring_mark_overflow(state)
            available.signal()
            return
        }
        let index = sotto_audio_ring_acquire_write(state)
        guard index >= 0 else {
            available.signal()
            return
        }

        let destination = slots[Int(index)]
        destination.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(
            source.mutableAudioBufferList
        )
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(
            destination.mutableAudioBufferList
        )
        guard sourceBuffers.count == destinationBuffers.count else {
            sotto_audio_ring_mark_overflow(state)
            available.signal()
            return
        }

        for index in sourceBuffers.indices {
            let sourceBuffer = sourceBuffers[index]
            let destinationBuffer = destinationBuffers[index]
            guard let sourceData = sourceBuffer.mData,
                  let destinationData = destinationBuffer.mData
            else {
                sotto_audio_ring_mark_overflow(state)
                available.signal()
                return
            }
            guard sourceBuffer.mDataByteSize <= destinationBuffer.mDataByteSize else {
                sotto_audio_ring_mark_overflow(state)
                available.signal()
                return
            }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
        }

        sotto_audio_ring_commit_write(state)
        available.signal()
    }

    func waitForNextBuffer() -> AVAudioPCMBuffer? {
        while true {
            available.wait()
            let index = sotto_audio_ring_acquire_read(state)
            if index >= 0 {
                return slots[Int(index)]
            }
            if !sotto_audio_ring_is_accepting(state) { return nil }
        }
    }

    func completeCurrentBuffer() {
        sotto_audio_ring_commit_read(state)
        if !sotto_audio_ring_is_accepting(state) {
            available.signal()
        }
    }

    func close() {
        sotto_audio_ring_close(state)
        available.signal()
    }
}
