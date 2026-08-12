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

