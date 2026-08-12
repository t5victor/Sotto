# Release process

## Local release

From an Apple Silicon Mac with Xcode 16 or newer:

```sh
swift test
Scripts/build-app.sh release
codesign --verify --deep --strict --verbose=2 dist/Sotto.app
spctl --assess --type execute --verbose=4 dist/Sotto.app
```

The script builds the release executable, constructs the standard macOS bundle,
copies the icon and legal notices, applies the microphone entitlement, performs
an ad-hoc hardened-runtime signature, verifies it and creates
`dist/Sotto-1.0.0.zip`.

An ad-hoc build is appropriate for local development. Gatekeeper assessment of
that artifact is expected to report that it has no trusted distribution origin.

## Public distribution

Public artifacts use the same bundle but replace the ad-hoc identity with the
publisher's Developer ID Application certificate, then notarize and staple:

```sh
codesign --force --deep --options runtime \
  --entitlements Sources/Sotto/Resources/Sotto.entitlements \
  --sign "Developer ID Application: ORGANIZATION (TEAMID)" dist/Sotto.app

ditto -c -k --sequesterRsrc --keepParent dist/Sotto.app dist/Sotto-1.0.0.zip
xcrun notarytool submit dist/Sotto-1.0.0.zip --keychain-profile NOTARY_PROFILE --wait
xcrun stapler staple dist/Sotto.app
spctl --assess --type execute --verbose=4 dist/Sotto.app
```

Certificate names and the notary profile are publisher credentials, not project
configuration, and are intentionally not stored in the repository.

## Runtime acceptance

Before publishing a build:

1. Launch the packaged app, install or validate Parakeet and confirm it reaches
   **Prepared**.
2. Grant Microphone and record a dictation longer than 0.18 seconds.
3. Verify insertion in a native text field with Accessibility enabled.
4. Revoke Accessibility and verify the clipboard fallback.
5. Quit, relaunch offline and dictate again without a model download.
6. Run `swift run SottoDoctor doctor` and the automated test suite.
