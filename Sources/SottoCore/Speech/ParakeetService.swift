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
