import AVFoundation
import FluidAudio
import Foundation
import SottoLocalization

public actor ParakeetService {
    public enum ServiceError: LocalizedError {
        case unsupportedHardware
        case modelNotInstalled
        case unreadableAudio(URL)
        case emptyAudio
        case emptyTranscript
        case languageMismatch(expected: SottoLanguage, detected: SottoLanguage)

        public var preservesRecordingForRetry: Bool {
            if case .languageMismatch = self { true } else { false }
        }

        public var errorDescription: String? {
            switch self {
            case .unsupportedHardware:
                SottoLocalization.string("error.parakeet.unsupported_hardware")
            case .modelNotInstalled:
                SottoLocalization.string("error.parakeet.model_not_installed")
            case .unreadableAudio(let url):
                SottoLocalization.format("error.parakeet.unreadable_audio", url.lastPathComponent)
            case .emptyAudio:
                SottoLocalization.string("error.parakeet.empty_audio")
            case .emptyTranscript:
                SottoLocalization.string("error.parakeet.empty_transcript")
            case .languageMismatch(let expected, let detected):
                SottoLocalization.format(
                    "error.parakeet.language_mismatch",
                    detected.displayName,
                    expected.displayName
                )
            }
        }
    }

    public nonisolated let updates: AsyncStream<SottoModelState>

    private let continuation: AsyncStream<SottoModelState>.Continuation
    private let directories: SottoDirectories
    private var manager: AsrManager?
    private var state: SottoModelState = .checking
    private var lastProgressPercent = -1
    private var lastProgressDetail = ""
    private var maximumDownloadProgress = 0.0
    private var activeDownloadID: UUID?
    private let languageDetector = SottoLanguageDetector()

    public init(directories: SottoDirectories) {
        self.directories = directories
        let pair = AsyncStream.makeStream(
            of: SottoModelState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.updates = pair.stream
        self.continuation = pair.continuation
        pair.continuation.yield(.checking)
    }

    deinit {
        continuation.finish()
    }

    @discardableResult
    public func inspect() -> SottoModelState {
        guard Self.isAppleSilicon else {
            return transition(to: .failed(message: ServiceError.unsupportedHardware.localizedDescription))
        }
        do {
            try directories.validateModelTree()
        } catch {
            return transition(to: .failed(message: Self.userMessage(for: error)))
        }

        let exists = AsrModels.modelsExist(
            at: directories.parakeetV3,
            version: .v3,
            encoderPrecision: .int8
        )
        if exists {
            return transition(to: .installed(bytes: modelSize()))
        }
        return transition(to: .notInstalled)
    }

    public func currentState() -> SottoModelState {
        state
    }

    public func install(replacingExisting: Bool = false) async throws {
        guard Self.isAppleSilicon else { throw ServiceError.unsupportedHardware }
        try directories.prepare()
        if replacingExisting {
            try await deleteModel()
        }
        try directories.validateModelTree()
        ModelHub.offlineMode = false
        lastProgressPercent = -1
        lastProgressDetail = ""
        maximumDownloadProgress = 0
        let downloadID = UUID()
        activeDownloadID = downloadID
        defer {
            if activeDownloadID == downloadID {
                activeDownloadID = nil
            }
        }

        do {
            transition(
                to: .downloading(
                    progress: 0,
                    detail: SottoLocalization.string("state.model.download_preparing")
                )
            )
            _ = try await AsrModels.download(
                to: directories.parakeetV3,
                version: .v3,
                encoderPrecision: .int8,
                progressHandler: { [weak self] progress in
                    Task { await self?.reportDownload(progress, downloadID: downloadID) }
                }
            )
            try Task.checkCancellation()
            transition(to: .validating)
            try directories.validateModelTree()
            try await loadModels()
        } catch is CancellationError {
            manager = nil
            _ = inspect()
            throw CancellationError()
        } catch {
            manager = nil
            transition(to: .failed(message: Self.userMessage(for: error)))
            throw error
        }
    }

    public func prepare() async throws {
        guard Self.isAppleSilicon else { throw ServiceError.unsupportedHardware }
        if manager != nil {
            transition(to: .ready(bytes: modelSize()))
            return
        }
        try directories.validateModelTree()
        guard AsrModels.modelsExist(
            at: directories.parakeetV3,
            version: .v3,
            encoderPrecision: .int8
        ) else {
            transition(to: .notInstalled)
            throw ServiceError.modelNotInstalled
        }
        ModelHub.offlineMode = true

        do {
            transition(to: .loading)
            try await loadModels()
        } catch {
            manager = nil
            transition(to: .failed(message: Self.userMessage(for: error)))
            throw error
        }
    }

    public func transcribe(
        audioURL: URL,
        language: SottoLanguage
    ) async throws -> SottoTranscript {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw ServiceError.unreadableAudio(audioURL)
        }
        guard audioFile.length > 0 else { throw ServiceError.emptyAudio }

        try Task.checkCancellation()
        try await prepare()
        try Task.checkCancellation()
        guard let manager else { throw ServiceError.modelNotInstalled }

        let resolvedLanguage = try await resolveLanguage(
            requested: language,
            audioFile: audioFile,
            manager: manager
        )
        var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(
            audioURL,
            decoderState: &decoderState,
            language: resolvedLanguage.fluidLanguage
        )
        try Task.checkCancellation()
        let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty else { throw ServiceError.emptyTranscript }

        if let mismatch = languageDetector.clearlyMismatchedLanguage(
            in: text,
            expected: resolvedLanguage
        ) {
            throw ServiceError.languageMismatch(
                expected: resolvedLanguage,
                detected: mismatch.language
            )
        }

        return SottoTranscript(
            text: text,
            confidence: result.confidence,
            duration: result.duration,
            processingTime: result.processingTime
        )
    }

    private func resolveLanguage(
        requested: SottoLanguage,
        audioFile: AVAudioFile,
        manager: AsrManager
    ) async throws -> SottoLanguage {
        guard requested == .automatic else { return requested }
        try Task.checkCancellation()

        do {
            guard let detected = try await detectLanguage(
                in: audioFile,
                manager: manager
            ) else {
                return .automatic
            }
            return detected
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // A short or noisy prefix must not prevent the full transcription;
            // automatic mode remains available as the conservative fallback.
            return .automatic
        }
    }

    private func detectLanguage(
        in audioFile: AVAudioFile,
        manager: AsrManager
    ) async throws -> SottoLanguage? {
        let format = audioFile.processingFormat
        let prefixFrameLimit = AVAudioFramePosition(
            (format.sampleRate * 6).rounded(.down)
        )
        let prefixFrames = min(audioFile.length, prefixFrameLimit)
        guard prefixFrames >= AVAudioFramePosition(format.sampleRate) else {
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(prefixFrames)
        ) else {
            return nil
        }
        audioFile.framePosition = 0
        try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(prefixFrames))
        guard buffer.frameLength > 0 else { return nil }

        let samples = try AudioConverter().resampleBuffer(buffer)
        guard samples.count >= 16_000 else { return nil }

        var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let prefixResult = try await manager.transcribe(
            samples,
            decoderState: &decoderState
        )
        try Task.checkCancellation()
        return languageDetector.detect(prefixResult.text)?.language
    }

    public func unload() async {
        if let manager {
            await manager.cleanup()
        }
        manager = nil
        _ = inspect()
    }

    public func deleteModel() async throws {
        if let manager {
            await manager.cleanup()
        }
        manager = nil

        let target = try directories.validateModelTarget()

        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        transition(to: .notInstalled)
    }

    private func loadModels() async throws {
        try directories.validateModelTree()
        let config = ASRConfig(
            streamingEnabled: true,
            streamingThreshold: 480_000,
            melChunkContext: false,
            dualDecodeArbitration: true
        )
        let models = try await AsrModels.load(
            from: directories.parakeetV3,
            version: .v3,
            encoderPrecision: .int8,
            progressHandler: { [weak self] progress in
                Task { await self?.reportLoading(progress) }
            }
        )
        try Task.checkCancellation()
        manager = AsrManager(config: config, models: models)
        ModelHub.offlineMode = true
        transition(to: .ready(bytes: modelSize()))
    }

    private func reportDownload(_ progress: DownloadProgress, downloadID: UUID) {
        guard activeDownloadID == downloadID else { return }
        let detail: String
        switch progress.phase {
        case .listing:
            detail = SottoLocalization.string("state.model.querying_files")
        case .downloading(let completed, let total):
            detail = total > 0
                ? SottoLocalization.format(
                    "state.model.downloading_file",
                    Int64(min(completed + 1, total)),
                    Int64(total)
                )
                : SottoLocalization.string("state.model.checking_files")
        case .compiling:
            detail = SottoLocalization.string("state.model.preparing_files")
        }
        maximumDownloadProgress = max(
            maximumDownloadProgress,
            min(max(progress.fractionCompleted, 0), 1)
        )
        let fraction = maximumDownloadProgress
        let percent = Int((fraction * 100).rounded(.down))
        guard percent != lastProgressPercent || detail != lastProgressDetail else { return }
        lastProgressPercent = percent
        lastProgressDetail = detail

        transition(
            to: .downloading(
                progress: fraction,
                detail: detail
            )
        )
    }

    private func reportLoading(_ progress: DownloadProgress) {
        _ = progress
        if case .ready = state { return }
        transition(to: .loading)
    }

    @discardableResult
    private func transition(to newState: SottoModelState) -> SottoModelState {
        guard newState != state else { return state }
        state = newState
        continuation.yield(newState)
        return newState
    }

    private func modelSize() -> Int64 {
        DirectorySize.bytes(at: directories.parakeetV3)
    }

    private static var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    private static func userMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

private extension SottoLanguage {
    var fluidLanguage: Language? {
        switch self {
        case .automatic: nil
        case .bulgarian: .bulgarian
        case .croatian: .croatian
        case .czech: .czech
        case .danish: .danish
        case .dutch: .dutch
        case .english: .english
        case .estonian: .estonian
        case .finnish: .finnish
        case .french: .french
        case .german: .german
        case .greek: .greek
        case .hungarian: .hungarian
        case .italian: .italian
        case .latvian: .latvian
        case .lithuanian: .lithuanian
        case .maltese: .maltese
        case .polish: .polish
        case .portuguese: .portuguese
        case .romanian: .romanian
        case .russian: .russian
        case .slovak: .slovak
        case .slovenian: .slovenian
        case .spanish: .spanish
        case .swedish: .swedish
        case .ukrainian: .ukrainian
        }
    }
}
