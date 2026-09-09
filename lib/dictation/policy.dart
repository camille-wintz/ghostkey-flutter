// The chunk policy — when a chunk is cut and when a session ends on its own.
// Ported from ghostkey-mobile `src/audio/useChunkedRecorder.ts`, constant for
// constant, with one deliberate difference noted on SILENCE_HOLD_MS.
//
// Pure: fed level samples and a clock, it answers with a decision. The
// recorder (session.dart) owns the clocks and the microphone; this file owns
// the numbers. Tested in test/dictation/policy_test.dart.

abstract final class DictationPolicy {
  /// Below this the sample is silence (RMS dBFS, metered every 100 ms).
  static const double silenceDbThreshold = -30;

  /// Gap that ends a chunk. The RN app holds 3000 ms because ITS recorder
  /// loses audio at every cut (stop → re-arm), so it cuts as rarely as it can.
  /// This recorder never stops — a cut is a file boundary in one continuous
  /// encoded stream — so a cut costs nothing, and the hold is the desktop's
  /// 1000 ms (ghost-key `useChunkedRecorder.ts`). Shorter is not better: the
  /// server's cleanup pass reads one chunk at a time, and dialogue split from
  /// its tag loses the context that pass needs.
  static const int silenceHoldMs = 1000;

  /// A chunk with less speech than this is dropped without a round trip.
  static const int minVoicedMs = 300;

  /// The metering cadence the native side reports at; one policy tick each.
  static const int pollIntervalMs = 100;

  /// The cap on a chunk nothing else cuts (unbroken speech, a noise floor
  /// above the threshold). Far above any plausible unbroken take: this cut
  /// lands wherever the speaker happens to be. Ten minutes of mono AAC at
  /// [bitRate] is ~4.8 MB, inside the server's 11 MB inline-audio line for the
  /// Gemini pipeline and its 25 MB per-chunk limit.
  static const int defaultMaxChunkMs = 10 * 60000;

  /// A chunk that never reached [minVoicedMs] is cut here and dropped locally,
  /// so an open mic in a pocket never holds a ten-minute file.
  static const int silentChunkMs = 60000;

  /// Nothing heard and nothing landed for this long — hang up.
  static const int idleStopMs = 5 * 60000;

  /// The unconditional ceiling on a session.
  static const int maxSessionMs = 60 * 60000;

  /// How much manuscript rides along with a chunk (the server clamps to the
  /// same budget; this keeps a long chapter off the wire).
  static const int previousChars = 600;

  /// How many earlier chunks ride along as `turns` (the server clamps to 4).
  static const int sessionTurns = 4;

  /// Retries on network-shaped failures before a chunk is given up.
  static const List<int> retryDelaysMs = [4000, 12000];

  /// An upload that has not answered by then is a failure (retryable).
  static const int uploadTimeoutMs = 120000;

  /// The recording preset: mono AAC-LC in `.m4a`. 64 kbps is the RN
  /// DICTATION_PRESET's bitrate; 16 kHz is speech-to-text's own rate and the
  /// one sample rate every Android device's AudioRecord supports.
  static const int sampleRate = 16000;
  static const int bitRate = 64000;

  /// Metering normalisation for the waveform (dB → 0..1).
  static const double floorDb = -50;
  static const double ceilDb = 0;
  static const int waveBars = 22;

  /// Files under `<cache>/dictation` older than this belong to no live
  /// session (RN `orphanedRecordings.ts` ORPHAN_AGE_MS).
  static const Duration orphanAge = Duration(seconds: 60);

  static double normalizeDb(double db) => ((db - floorDb) / (ceilDb - floorDb)).clamp(0, 1);
}

/// Why the recorder cut the running chunk.
enum CutReason { silence, silentChunk, cap }

/// Why a session ended without the writer tapping pause or Done. `idle` and
/// `ceiling` are the policy's own clocks; `locked` is a foreground-only
/// session meeting the lock screen; `stopped` is the Stop action on the
/// recording notification.
enum AutoStopReason { idle, ceiling, locked, stopped }

sealed class PolicyDecision {
  const PolicyDecision();
}

class KeepGoing extends PolicyDecision {
  const KeepGoing();
}

class CutChunk extends PolicyDecision {
  const CutChunk(this.reason);
  final CutReason reason;
}

class EndSession extends PolicyDecision {
  const EndSession(this.reason);
  final AutoStopReason reason;
}

/// The state machine of one session: the chunk's voiced/silence counters and
/// the three clocks (session start, last activity, chunk start). All times
/// are milliseconds on whatever clock the caller keeps.
class SessionPolicy {
  SessionPolicy({this.maxChunkMs = DictationPolicy.defaultMaxChunkMs});

  final int maxChunkMs;

  int _sessionStartedAt = 0;
  int _lastActivityAt = 0;
  int _chunkStartedAt = 0;

  /// Speech heard in the running chunk.
  int voicedMs = 0;

  /// Silence since the last speech, once the chunk has [DictationPolicy.minVoicedMs].
  int silenceMs = 0;

  /// Chunks uploading or waiting to land. Idle never fires while any are.
  int pending = 0;

  /// Whether the running chunk holds enough speech to be worth a round trip.
  bool get chunkVoiced => voicedMs >= DictationPolicy.minVoicedMs;

  void startSession(int nowMs) {
    _sessionStartedAt = nowMs;
    _lastActivityAt = nowMs;
    startChunk(nowMs);
  }

  void startChunk(int nowMs) {
    _chunkStartedAt = nowMs;
    voicedMs = 0;
    silenceMs = 0;
  }

  /// A sign the session is in use: a chunk that heard speech, or a transcript
  /// that came back with text.
  void noteActivity(int nowMs) => _lastActivityAt = nowMs;

  /// One metering sample of [sampleMs] of audio at [db], at wall time [nowMs].
  /// Same order of checks as the RN loop: silence hold, ceiling, idle,
  /// never-voiced cut, cap.
  PolicyDecision onLevel({
    required double db,
    required int nowMs,
    int sampleMs = DictationPolicy.pollIntervalMs,
  }) {
    if (db >= DictationPolicy.silenceDbThreshold) {
      voicedMs += sampleMs;
      silenceMs = 0;
    } else if (voicedMs >= DictationPolicy.minVoicedMs) {
      silenceMs += sampleMs;
      if (silenceMs >= DictationPolicy.silenceHoldMs) return const CutChunk(CutReason.silence);
    }
    if (nowMs - _sessionStartedAt >= DictationPolicy.maxSessionMs) {
      return const EndSession(AutoStopReason.ceiling);
    }
    if (pending == 0 && nowMs - _lastActivityAt >= DictationPolicy.idleStopMs) {
      return const EndSession(AutoStopReason.idle);
    }
    if (voicedMs < DictationPolicy.minVoicedMs && nowMs - _chunkStartedAt >= DictationPolicy.silentChunkMs) {
      return const CutChunk(CutReason.silentChunk);
    }
    if (nowMs - _chunkStartedAt >= maxChunkMs) return const CutChunk(CutReason.cap);
    return const KeepGoing();
  }
}
