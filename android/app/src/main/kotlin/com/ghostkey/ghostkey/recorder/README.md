# The dictation recorder (Android)

One continuous `AudioRecord` per session, encoded by one `MediaCodec` AAC-LC
encoder, cut into `.m4a` files at the boundaries the Dart policy asks for. The
microphone never stops between chunks: a chunk is a cut of the encoded
stream, not a recording of its own. This closes the seam the RN app has
(`../ghostkey-mobile/docs/dictation-parity-plan.md`, gap 8): 0 ms of audio
lost between chunk *N* and *N+1*.

| File | Role |
| --- | --- |
| `RecorderPlugin.kt` | The Flutter plugin: `MethodChannel ghostkey/recorder`, `EventChannel ghostkey/recorder/events`, runtime permissions. Registered from `MainActivity`. |
| `DictationService.kt` | The microphone-type foreground service that owns the session: the capture thread, metering, wake lock, notification with Stop. Singleton (`instance`). |
| `AacChunkWriter.kt` | The encoder + per-file `MediaMuxer`; `cutAt()` rotates files on an AU boundary. |

Dart side: `lib/dictation/recorder_channel.dart` is the only caller.

## Methods (`ghostkey/recorder`)

| Method | Arguments | Returns |
| --- | --- | --- |
| `permissions` | — | `{sdk, microphone, notifications}` |
| `requestMicrophone` | — | `bool` (RECORD_AUDIO) |
| `requestNotifications` | — | `bool` (POST_NOTIFICATIONS; always true below API 33) |
| `chunkDirectory` | — | `<cacheDir>/dictation` |
| `start` | `{sessionId, sampleRate=16000, bitRate=64000, silenceDb=-30, minVoicedMs=300, wakeLockMs, audioSource='mic'|'voice_recognition'|'voice_communication', title, text}` | `sessionId`; the session is live once the `started` event arrives. Errors: `microphone_denied`, `service_start_refused`. |
| `cut` | — | path of the file being finished (the `chunk` event follows), or null with no session |
| `pause` | — | same as `cut`; the mic stays open, nothing is encoded until `resume` |
| `resume` | — | null |
| `stop` | — | path of the last file (the `chunk` and `stopped` events follow), or null |
| `isRunning` | — | `bool` |

`start` must be called while the activity is visible (Android 14's rule for a
microphone service). It checks RECORD_AUDIO itself; POST_NOTIFICATIONS is
Dart's decision (see `lib/dictation/background_mode.dart`) — without it the
service still runs and records, but the OS shows no notification, so Dart
runs the session foreground-only and ends it on lock.

## Events (`ghostkey/recorder/events`), all maps with an `event` key

| `event` | Fields | When |
| --- | --- | --- |
| `started` | `sessionId, sampleRate, backgroundCapable` | AudioRecord is running. `backgroundCapable=false` means `startForeground` was refused; the session records only while visible. |
| `level` | `db` (dBFS, RMS over the window, −160 for digital silence), `elapsedMs` (audio time fed to the encoder: excludes pauses) | every 100 ms of audio |
| `chunk` | `index, path, startFrame, endFrame, durationMs, startMs, endMs, heardSpeech, voicedMs` | a file closed — after `cut`/`pause`/`stop`, or a native end |
| `stopped` | `reason` ∈ `client` \| `notification` \| `task_removed` \| `error` \| `restarted` \| `destroyed`, `samplesIn`, `framesOut` | the session is over; the last `chunk` event (if any) precedes it |
| `error` | `code, message` | `audio_record_unavailable`, `encoder_unavailable`, `audio_record_start_failed`, `capture_failed` |

A `stopped` whose reason is not `client` is the native side ending the
session on its own — the notification's Stop action, the app swiped from
recents — and the Dart loop treats it as an auto-stop, not as its own.

## The seam

- The capture thread reads `AudioRecord` in 20 ms blocks into a 2-second
  hardware buffer (so a late thread never overruns), feeds every block to the
  encoder, and meters RMS → dBFS per 100 ms of audio.
- The encoder emits AAC-LC access units of exactly 1024 samples. Every AU is
  a sync sample; there is no inter-frame prediction, so the AU sequence can
  be split between two MP4 files at any boundary.
- `cutAt(sample)` marks the AU index `ceil(sample / 1024)` (never behind the
  AUs already written, so a file is never empty). AUs below it go to the open
  file, the AU at it opens the next. The boundary lands within one AU
  (64 ms at 16 kHz) of the request, always after the audio asked to be kept.
- Per-file timestamps are counted (`frameInFile × 1024 / rate`), not copied
  from the encoder, so each file's timeline is its AUs end to end.
- While paused the mic keeps running (a resume has no re-arm); nothing is
  encoded except the ≤2 AUs of silence a pending cut still needs to emerge.

**Accounting.** `samplesIn` (PCM fed) and `framesOut` (AUs written) are
carried on `stopped`; every `chunk` carries `startFrame`/`endFrame`. The
Dart `SeamLedger` (`lib/dictation/seam_ledger.dart`, unit-tested) checks
`chunk[k].startFrame == chunk[k-1].endFrame` for every pair and
`framesOut × 1024 ≥ samplesIn` at the end, and logs a gap if there is one.

**Metronome test (author, on the phone).** Play a 1 s click track through a
speaker, dictate a sentence, pause 2 s (a silence cut), dictate another.
Concatenate the session's chunk files (`ffmpeg -f concat`) and count clicks:
the count must equal the wall-clock seconds, and no click may be doubled or
missing at any file boundary. Repeat with a 10-minute cap cut mid-speech; the
word across the boundary must appear once, whole, across the two transcripts.

## Not verified here

The Kotlin was written against API 24–37 without a compile (one phone, one
Gradle lock, several agents). First build: check `MediaCodec` input buffer
capacity on the device (the writer slices to it), that `c2.android.aac.encoder`
accepts 16 kHz mono at 64 kbps (the writer falls back to 44.1/48 kHz for
`AudioRecord` only; the bit rate is fixed), and that a 20 ms `read` on a
2-second buffer keeps up under lock on a Samsung.
