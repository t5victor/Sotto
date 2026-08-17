# Privacy model

Sotto performs recognition on the Mac. It contains no analytics,
advertising SDK, account system, telemetry endpoint or cloud transcription API.

## Network behavior

The network is used when the user selects **Download model**. FluidAudio
downloads the converted Parakeet Core ML artifacts from the FluidInference
repository on Hugging Face. After the model loads, Sotto enables FluidAudio's
offline mode. Dictation itself does not make a network request.

## Local data

All application data is under `~/Library/Application Support/Sotto`:

- `Models/` contains the downloaded model (about 483 MB for the validated v1
  artifact set).
- `State/preferences.json` contains UI and dictation preferences.
- `State/vocabulary.json` contains user-defined replacements.
- `State/history.json` is written only when local history is on. Each record
  contains the recognized raw text, processed text, creation date, audio
  duration, processing time, model confidence, destination application name
  (when available) and insertion outcome. It does not contain audio.
- `Recordings/` is transient. Sotto deletes audio after processing or
  cancellation and removes crash leftovers older than 24 hours at startup.

The user can delete the model and history from the app. Disabling history stops
new records, but existing records remain visible until the user deletes them.

## Permissions

- **Microphone** is required to capture speech.
- **Accessibility** is optional and used only to insert text into the previously
  active application. Without it, Sotto copies the completed text.
- **Launch at login** is optional and managed with `SMAppService`.

The Command-V fallback temporarily uses the system pasteboard only when it is
empty. macOS provides no trustworthy size metadata for existing pasteboard
values, so Sotto never materializes strings, images, files, rich text or
promised/lazy values on the main actor just to snapshot them. When the pasteboard
already contains something, Sotto copies the text instead of simulating a paste.
Because macOS exposes no API that confirms a synthetic Command-V changed the
destination, history records that fallback as **Pegado solicitado**, not as a
verified insertion.

## Retention and recovery

Recordings stop automatically at the duration selected in Settings (five minutes
by default, configurable between two and thirty minutes). The user can cancel
both capture and local transcription. Sotto deletes the temporary CAF after
success, failure or cancellation and removes crash leftovers older than 24 hours
at startup. Managed state, model and recording paths reject symbolic links before
reading, writing or deleting data.
