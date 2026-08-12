# Version 1.0 validation

Validation date: 2026-08-12. Host: Apple M4, 16 GB RAM, arm64, macOS 26.5.2.

## Automated checks

- `swift test`: 15 tests passed, 0 failures.
- Coverage includes theme replacement, text processing, vocabulary identity,
  corrupt JSON recovery, bounded history, stale recording cleanup, offline model
  inspection and deletion constrained to the exact model directory.
- Release bundle: valid ad-hoc hardened-runtime signature, arm64 Mach-O, version
  1.0.0, microphone entitlement and valid Info.plist.
- `unzip -t dist/Sotto-1.0.0.zip`: no errors.

## Model and transcription

- Parakeet TDT 0.6B v3 int8 downloaded and loaded from the Sotto application
  support directory: 483,256,769 bytes.
- Core ML selected CPU for preprocessing and CPU + Neural Engine for the encoder.
- A 4.373 s Spanish fixture transcribed in 0.131 s (33.4x realtime) with 0.985
  confidence. Raw `Soto` became final `Sotto` through the default editable
  vocabulary.
- The model was subsequently loaded and used with FluidAudio offline mode on.

## Packaged application

- `dist/Sotto.app` launched successfully with bundle identifier
  `com.sotto.desktop` and remained running after model initialization.
- A live dictation from the packaged app captured 14.6 s of microphone audio,
  transcribed it in 0.179 s (about 81.8x realtime) at 0.935 confidence, removed
  the temporary CAF and persisted the completed record. Because Sotto itself was
  the active target, the safety route correctly reported `copied`.
- The Accessibility route was exercised separately against a temporary TextEdit
  document and reported `TARGET=TextEdit`, `OUTCOME=inserted`.
- Independent microphone diagnostics captured 350,400 mono Float32 frames at
  48 kHz over 7.3 s without a realtime-thread isolation failure.

## Final artifact

- App: `dist/Sotto.app` (approximately 9.7 MB; model stored separately).
- Archive: `dist/Sotto-1.0.0.zip` (approximately 3.8 MB).
- SHA-256:
  `e871b528de7755dac12721de7402036fb77734fbfa028e7a924672991ae4b1d9`.
