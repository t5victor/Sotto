# Release process

## Local release

From an Apple Silicon Mac with Xcode 16 or newer:

```sh
swift test
Scripts/build-app.sh release local
codesign --verify --deep --strict --verbose=2 dist/Sotto.app
spctl --assess --type execute --verbose=4 dist/Sotto.app
```

The script builds the release executable, constructs the standard macOS bundle,
copies the icon and legal notices, applies the microphone entitlement, performs
an ad-hoc hardened-runtime signature, verifies it, creates
`dist/Sotto-1.0.0.zip` and writes its exact digest beside it as
`dist/Sotto-1.0.0.zip.sha256`.

An ad-hoc build is appropriate for local development. Gatekeeper assessment of
that artifact is expected to report that it has no trusted distribution origin.

## Public distribution

Public artifacts use a separate fail-closed mode. It requires the publisher's
Developer ID Application certificate and an existing notarytool keychain
profile, then signs, notarizes, staples, assesses and regenerates the final
archive/checksum:

```sh
SOTTO_CODESIGN_IDENTITY="Developer ID Application: ORGANIZATION (TEAMID)" \
SOTTO_NOTARY_PROFILE="NOTARY_PROFILE" \
  Scripts/build-app.sh release public
```

Certificate names and the notary profile are publisher credentials, not project
configuration, and are intentionally not stored in the repository. The script
refuses a public build when either value is missing. Until this command
completes with real publisher credentials, an artifact is a local build and is
not ready for public distribution.

## Runtime acceptance

Before publishing a build:

1. Launch the packaged app, install or validate Parakeet and confirm it reaches
   **Prepared**.
2. Grant Microphone and record a dictation longer than 0.18 seconds.
3. Verify insertion in a native text field with Accessibility enabled.
4. Revoke Accessibility and verify the clipboard fallback.
5. With Accessibility enabled, an empty pasteboard and a control that rejects
   AX selected text, verify the UI reports **Pegado solicitado**, not a verified
   insertion.
6. Quit, relaunch offline and dictate again without a model download.
7. Run `swift run SottoDoctor doctor` and the automated test suite.
