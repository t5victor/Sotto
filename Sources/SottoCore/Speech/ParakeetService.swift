import AVFoundation
import FluidAudio
import Foundation

public actor ParakeetService {
    public enum ServiceError: LocalizedError {
        case unsupportedHardware
        case modelNotInstalled
        case unreadableAudio(URL)
        case emptyAudio
        case emptyTranscript

        public var errorDescription: String? {
            switch self {
            case .unsupportedHardware:
                "Parakeet requiere un Mac con Apple Silicon."
            case .modelNotInstalled:
                "Descarga Parakeet antes de iniciar el dictado."
            case .unreadableAudio(let url):
                "No se pudo leer la grabación \(url.lastPathComponent)."
            case .emptyAudio:
                "La grabación no contiene audio suficiente para transcribir."
            case .emptyTranscript:
                "No se detectó voz en la grabación."
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

    public func install() async throws {
        guard Self.isAppleSilicon else { throw ServiceError.unsupportedHardware }
        try directories.prepare()
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
            transition(to: .downloading(progress: 0, detail: "Preparando descarga"))
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

