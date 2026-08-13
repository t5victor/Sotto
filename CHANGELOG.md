# Changelog

## 1.0.0 — 2026-08-13

- Added native macOS app, menu bar control and non-activating dictation overlay.
- Added Parakeet TDT 0.6B v3 download, progress, validation, offline loading and
  deletion through FluidAudio/Core ML.
- Added real microphone capture, level metering and transient recording cleanup.
- Added 25-language transcription, vocabulary replacement, filler removal and
  normalization.
- Added global hold/toggle shortcuts and three-stage text insertion fallback.
- Added local preferences, bounded history, launch at login and permission UI.
- Added source-owned, themeable SwiftUI component system.
- Added SottoDoctor, automated tests, app icon and release packaging.
- Hardened realtime capture with a preallocated lock-free C11 ring, bounded
  recording duration and cancellation during local transcription.
- Hardened target identity, pasteboard behavior, symlink-safe managed paths,
  recoverable model installation and versioned local persistence.
- Added accessible light/dark color pairs, complete fastcluster attribution,
  CI, portable artifact checksums and fail-closed Developer ID notarization.
- Rebuilt the interface around the Beautiful UI art direction: bundled Inter
  and JetBrains Mono, exact light/dark neutral tokens, compact one-pixel
  controls, custom sidebar hover states, outline icon sizing and restrained
  pixel-loader, shimmer, reveal and press motion with Reduce Motion support.
