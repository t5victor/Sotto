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
                defaultValue: SottoPreferences.default
            )
            let vocabularyStore = SottoVocabularyRepository(url: directories.vocabularyFile)
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
