# Privacy model

Sotto performs recognition on the Mac. The application contains no analytics,
advertising SDK, account system, telemetry endpoint or cloud transcription API.

## Network behavior

The network is used when the user selects **Download model**. FluidAudio obtains
the converted Parakeet Core ML artifacts from the FluidInference repository on
Hugging Face. After a complete model has loaded, Sotto enables FluidAudio's
offline mode; dictation itself does not make a network request.

## Local data

All application data is under `~/Library/Application Support/Sotto`:

- `Models/` contains the downloaded model (about 483 MB for the validated v1
  artifact set).
- `State/preferences.json` contains UI and dictation preferences.
- `State/vocabulary.json` contains user-defined replacements.
- `State/history.json` contains completed text only when local history is on.
- `Recordings/` is transient. Sotto deletes audio after processing or
  cancellation and removes crash leftovers older than 24 hours at startup.

The user can delete the model and history from the app. Disabling history stops
new records; existing records remain visible so deletion is deliberate rather
than surprising.

## Permissions

- **Microphone** is required to capture speech.
- **Accessibility** is optional and used only to insert text into the previously
  active application. Without it, Sotto copies the completed text.
- **Launch at login** is optional and managed with `SMAppService`.

The Command-V fallback temporarily uses the system pasteboard. Sotto snapshots
its existing items and restores them after the paste if no other application
changes the pasteboard in the meantime.
