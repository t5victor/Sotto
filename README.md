# Sotto

Sotto is a native macOS dictation application that turns speech into text
without sending audio to a transcription service. It records the microphone,
runs NVIDIA Parakeet TDT 0.6B v3 locally through Core ML, cleans the result and
inserts it into the application that was active when dictation began.

Version 1.0 includes the complete desktop flow:

- resumable model installation with byte progress, validation, offline reload
  and safe deletion;
- microphone capture to a private scratch recording with a live level meter;
- local multilingual transcription in 25 languages on Apple Silicon;
- editable vocabulary, conservative filler removal and text normalization;
- global hold-to-talk or toggle shortcut (Option-Space by default);
- direct Accessibility insertion, Command-V fallback and clipboard fallback;
- non-activating overlay, menu bar controls and launch-at-login support;
- local preferences and optional, bounded transcription history;
- a source-owned SwiftUI design system inspired by shadcn/ui and visually
  aligned with Beautiful UI;
- a diagnostic CLI, automated tests and a reproducible `.app` packager.

## Requirements

- an Apple Silicon Mac;
- macOS 14 or newer;
- about 500 MB of free space for the Parakeet Core ML model;
- Xcode 16 or newer only when building from source.

## Install and use

Build the local release:

```sh
Scripts/build-app.sh release local
open dist/Sotto.app
```

On first launch:

1. Open **Models** and select **Download model**. This is the only operation
   that needs a network connection.
2. Grant Microphone permission.
3. Grant Accessibility permission if Sotto should insert text automatically.
   Without it, completed text remains safely available on the clipboard.
4. Hold **Option-Space**, speak, then release. Disable “Hold to dictate” to use
   the same shortcut as an on/off toggle.

The app captures the target application and its process identity before asking
for microphone permission or showing its overlay, so neither macOS's permission
UI nor Sotto itself becomes the text destination.

## Build and test

```sh
swift test
swift run Sotto
Scripts/build-app.sh release local
```

`build-app.sh` creates an ad-hoc signed local build at `dist/Sotto.app` and a
transport archive at `dist/Sotto-1.0.0.zip`, plus its matching `.sha256`.
A public download can be signed and
notarized with the publisher's Apple Developer identity without changing the
application code; see [Documentation/Release.md](Documentation/Release.md).

## Diagnostics

`SottoDoctor` exercises the same `SottoCore` services as the UI:

```sh
swift run SottoDoctor doctor
swift run SottoDoctor install-model
swift run SottoDoctor validate-model
swift run SottoDoctor record 5 /tmp/sotto-test.caf
swift run SottoDoctor transcribe /path/to/audio
swift run SottoDoctor insert "Texto de prueba"
```

## Project map

```text
Sources/
├── Sotto/                 SwiftUI app, menu bar and overlay
├── SottoCore/             audio, Parakeet, text, persistence and macOS services
├── SottoAudioRingC/       lock-free C11 SPSC indices for realtime audio
├── SottoDesignSystem/     owned tokens, components and product patterns
└── SottoDoctor/           runtime diagnostics
Tests/
├── SottoCoreTests/
└── SottoDesignSystemTests/
```

More detail:

- [Architecture](Documentation/Architecture.md)
- [Privacy model](Documentation/Privacy.md)
- [Design system](Documentation/DesignSystem.md)
- [Release process](Documentation/Release.md)
- [Version 1.0 validation](Documentation/Validation.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

Sotto is licensed under Apache License 2.0. The separately downloaded Parakeet
model is licensed under CC BY 4.0; attribution is included in the app and in the
third-party notices.
