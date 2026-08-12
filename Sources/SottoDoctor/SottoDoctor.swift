import Foundation
import SottoCore

@main
struct SottoDoctor {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(message(for: error))\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func run(arguments: [String]) async throws {
        let command = arguments.first ?? "doctor"
        let directories = SottoDirectories.live
        try directories.prepare()
        let service = ParakeetService(directories: directories)

        let observer = Task {
            for await state in service.updates {
                printState(state)
            }
        }
        defer { observer.cancel() }

        switch command {
        case "doctor":
            print("Sotto Doctor")
            print("Architecture: \(architecture)")
            print("Data directory: \(directories.root.path)")
            let state = await service.inspect()
            printState(state)
            print("Microphone: \(SottoPermissionService.microphoneStatus().rawValue)")
            print("Accessibility: \(SottoPermissionService.accessibilityStatus().rawValue)")

        case "install-model":
            try await service.install()
            print("Parakeet installed and loaded successfully.")

        case "validate-model":
            let state = await service.inspect()
            guard state.isInstalled else {
                throw ParakeetService.ServiceError.modelNotInstalled
            }
            try await service.prepare()
            print("Parakeet model loaded successfully.")

        case "transcribe":
            guard arguments.count == 2 else { throw DoctorError.missingAudioPath }
            let url = URL(fileURLWithPath: arguments[1]).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw DoctorError.audioNotFound(url)
            }
            let result = try await service.transcribe(audioURL: url, language: .spanish)
            let settingsStore = JSONFileStore(
                url: directories.preferencesFile,
                defaultValue: SottoPreferences.default,
                managedRoot: directories.root,
                managedDirectory: directories.state
            )
            let vocabularyStore = SottoVocabularyRepository(
                url: directories.vocabularyFile,
                managedRoot: directories.root,
                managedDirectory: directories.state
            )
            let preferences = await settingsStore.load()
            let vocabulary = await vocabularyStore.load()
            let text = TextPostProcessor().process(
                result.text,
                preferences: preferences,
                vocabulary: vocabulary
            )
            print("RAW_TEXT=\(result.text)")
            print("TEXT=\(text)")
            print("DURATION=\(String(format: "%.3f", result.duration))")
            print("PROCESSING=\(String(format: "%.3f", result.processingTime))")
            print("RTFX=\(String(format: "%.1f", result.realTimeFactor))")
            print("CONFIDENCE=\(String(format: "%.3f", result.confidence))")

        case "record":
            guard arguments.count == 3,
                  let seconds = Double(arguments[1]),
                  (0.2...300).contains(seconds)
            else { throw DoctorError.invalidRecordArguments }
            let url = URL(fileURLWithPath: arguments[2]).standardizedFileURL
            let audio = try await recordMicrophone(seconds: seconds, to: url)
            print("AUDIO=\(audio.url.path)")
            print("DURATION=\(String(format: "%.3f", audio.duration))")
            print("FRAMES=\(audio.frameCount)")
            print("PEAK=\(String(format: "%.3f", audio.peakLevel))")

        case "insert":
            let text = arguments.dropFirst().joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw DoctorError.missingInsertionText }
            let result = await insertIntoFrontmostApplication(text)
            print("TARGET=\(result.target?.applicationName ?? "none")")
            print("OUTCOME=\(result.outcome.rawValue)")

        default:
            throw DoctorError.unknownCommand(command)
        }
    }

    private static func printState(_ state: SottoModelState) {
        switch state {
        case .checking:
            print("MODEL checking")
        case .notInstalled:
            print("MODEL not-installed")
        case .installed(let bytes):
            print("MODEL installed bytes=\(bytes)")
        case .downloading(let progress, let detail):
            print("MODEL downloading \(Int(progress * 100))% \(detail)")
        case .validating:
            print("MODEL validating")
        case .loading:
            print("MODEL loading")
        case .ready(let bytes):
            print("MODEL ready bytes=\(bytes)")
        case .failed(let message):
            print("MODEL failed \(message)")
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64 (Apple Silicon)"
        #else
        "unsupported"
        #endif
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    @MainActor
    private static func recordMicrophone(seconds: Double, to url: URL) async throws -> RecordedAudio {
        let recorder = MicrophoneRecorder()
        do {
            try recorder.start(writingTo: url)
            try await Task.sleep(for: .seconds(seconds))
            return try recorder.stop()
        } catch {
            recorder.cancel()
            throw error
        }
    }

    @MainActor
    private static func insertIntoFrontmostApplication(
        _ text: String
    ) async -> (target: InsertionTargetInfo?, outcome: TextInsertionOutcome) {
        let inserter = TextInsertionService()
        let target = inserter.captureTarget()
        let outcome = await inserter.insert(text, automatically: true)
        return (target, outcome)
    }

    private enum DoctorError: LocalizedError {
        case missingAudioPath
        case invalidRecordArguments
        case missingInsertionText
        case audioNotFound(URL)
        case unknownCommand(String)

        var errorDescription: String? {
            switch self {
            case .missingAudioPath:
                "Uso: swift run SottoDoctor transcribe /ruta/al/audio"
            case .invalidRecordArguments:
                "Uso: swift run SottoDoctor record SEGUNDOS /ruta/de/salida.caf (0,2–300 s)"
            case .missingInsertionText:
                "Uso: swift run SottoDoctor insert TEXTO"
            case .audioNotFound(let url):
                "No existe el audio: \(url.path)"
            case .unknownCommand(let command):
                "Comando desconocido: \(command). Usa doctor, install-model, validate-model, record, transcribe o insert."
            }
        }
    }
}
