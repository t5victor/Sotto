# Version 1.0 validation

Validation date: 2026-08-13. Host: Apple M4, 16 GB RAM, arm64, macOS 26.5.2.

## Automated checks

- `swift test`: 29 tests passed, 0 failures.
- Coverage includes C11 SPSC ring ordering/overflow, hardware-quantum capacity,
  target identity beyond PID, theme replacement, WCAG/APCA pairs, text
  processing, vocabulary identity, schema migration, corrupt JSON recovery,
  bounded history, stale recording cleanup, symlink-parent attacks, offline
  model inspection, safe model deletion and invalid-audio preflight.
- Local bundle: valid ad-hoc hardened-runtime signature, arm64 Mach-O, version
  1.0.0, microphone entitlement and valid Info.plist.
- `unzip -t dist/Sotto-1.0.0.zip`: no errors.
- The ZIP contains no `__MACOSX`/AppleDouble duplicates; the app extracted from
  it passes `codesign --verify --deep --strict`.
- The linked `fastcluster_compute_centroid_linkage` symbol and complete
  fastcluster BSD notice are both present in the local bundle.

## Model and transcription

- Parakeet TDT 0.6B v3 int8 downloaded and loaded from the Sotto application
  support directory: 483,256,769 bytes.
- Core ML selected CPU for preprocessing and CPU + Neural Engine for the encoder.
- A 4.373 s Spanish fixture transcribed in 0.131 s (33.4x realtime) with 0.985
  confidence. Raw `Soto` became final `Sotto` through the default editable
  vocabulary.
- `SottoDoctor validate-model` found the complete 483,256,769-byte local cache,
  performed no download, loaded the 8,192-token vocabulary and all Core ML
  artifacts, and reached `MODEL ready`.

## Runtime acceptance

- The corrected lock-free audio path was exercised against the physical input.
  Core Audio supplied 4,800-frame hardware blocks at 48 kHz despite a 2,048
  tap request; the final capacity policy handled them without overflow.
- `SottoDoctor record 2` produced a mono 48 kHz Float32 CAF containing 100,800
  valid frames (2.100 s), 403,200 audio bytes and peak level 0.655. The
  incidental test audio was deleted immediately after format validation.

The following full-UI checks were completed on 2026-08-12, before the corrective
patch, and remain useful historical evidence rather than proof of the final
notarized candidate:

- `dist/Sotto.app` launched successfully with bundle identifier
  `com.sotto.desktop` and remained running after model initialization.
- A live dictation from the packaged app captured 14.6 s of microphone audio,
  transcribed it in 0.179 s (about 81.8x realtime) at 0.935 confidence, removed
  the temporary CAF and persisted the completed record. Because Sotto itself was
  the active target, the safety route correctly reported `copied`.
- The Accessibility route was exercised separately against a temporary TextEdit
  document and reported `TARGET=TextEdit`, `OUTCOME=inserted`.
## Current local artifact

- App: `dist/Sotto.app` (approximately 9.7 MB; model stored separately).
- Archive: `dist/Sotto-1.0.0.zip` (approximately 3.8 MB).
- SHA-256:
  `47d72dd83740fe7de45428786270f534e94228a49ea447c0b60f5965e897b011`.
- The matching digest is emitted in `dist/Sotto-1.0.0.zip.sha256`, beside the
  exact archive it describes, and `shasum -a 256 -c` passes.

## Public release gate

This document does not claim a Developer ID or notarized build. Public release
requires `Scripts/build-app.sh release public` with real publisher credentials,
a successful notary submission, stapling and Gatekeeper assessment. Those
credential-dependent checks remain external to source-level validation.
