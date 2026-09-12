// What counts as silence, measured from the room rather than fixed in advance.
//
// Ported from ghost-key `src/shared/audio/roomMeter.ts`, in dBFS rather than
// linear amplitude because that is the unit the native recorder reports and
// the unit policy.dart has always thought in. Every ratio there is a sum
// here: ×2.5 is +8 dB, ×0.25 is −12 dB, ×2 is +6 dB. Percentiles are
// unaffected by the change of unit — dB is monotonic in amplitude, so the
// same sample is the 5th percentile either way.
//
// The chunk policy decides three things off one comparison — is this sample
// speech, has the writer paused long enough to cut a chunk, and did this
// chunk hold enough speech to be worth sending — and all three used the
// constant [fallbackThresholdDb] (−30 dBFS). A constant is
// wrong in both directions, and each direction costs something different:
//
//   A room LOUDER than the line: every sample reads as speech, so the
//   silence hold never arms and no chunk is ever cut at a pause. Chunks then
//   run to the ten-minute cap — ten minutes of a fan, transcribed, with the
//   writer waiting ten minutes for their text. `silentChunkMs` cannot save
//   this one either: the chunk IS voiced by that line.
//
//   A voice QUIETER than the line: no sample reads as speech, `voicedMs`
//   never reaches `minVoicedMs`, and the chunk is discarded unsent. This is
//   the expensive one — a soft-spoken author, or a phone held at arm's
//   length, loses dictation silently with nothing anywhere to show it
//   happened.
//
// So the line is read from the room continuously: the quiet part of a
// rolling window is the floor, and speech is what stands clear of it. Same
// idea as the session floor in erase_silence.dart and deliberately NOT the
// same number — that one is measured on decoded chunk audio after the fact,
// this one on the recorder's live metering, and mixing readings from two
// different signal paths would make both harder to reason about than
// keeping two.
//
// Pure, and separate from the policy for that reason: fed a sequence of
// levels it answers with a threshold, so the behaviour can be checked
// against a room without a microphone (test/dictation/room_meter_test.dart).

/// The line before the room has been measured, and the fallback whenever a
/// reading cannot be taken (RMS dBFS). The constant this module replaces,
/// re-exported by policy.dart as `DictationPolicy.silenceDbThreshold` — a
/// session's first [warmupMs] behave exactly as every session did before
/// this module existed.
const double fallbackThresholdDb = -30;

/// How much recent audio the floor is read from. Long enough to contain a
/// pause in almost any speaking rhythm, short enough to follow a room that
/// changes — a window opened, a fan started.
const int floorWindowMs = 30000;

/// Until the window holds this much audio the reading is not trusted and the
/// old fixed line stands. A session opens behaving exactly as it did before
/// this module existed.
const int warmupMs = 3000;

/// Speech is this far above the floor — the ROOM_SNR of erase_silence.dart,
/// and for the same reason: it is the margin at which a voice stops being
/// confusable with the room it is in.
const double voiceOverRoomDb = 8;

/// The threshold never rises past this far under what the window's loud
/// moments are, so a window made entirely of speech cannot walk the line up
/// into the speech itself and start reading a writer's own voice as a pause.
/// Applied only when the window HAS loud moments — see `_hasContrast`.
const double speechClampDb = -12;

/// Whether the window holds anything above its own floor at all. Below this
/// the window is one flat sound (an empty room, a hum) and the speech clamp
/// is meaningless — worse than meaningless, since it would drag the line
/// back under a loud room and hide the pauses this module exists to find.
const double contrastDb = 6;

/// Floor and ceiling on the answer. The low one keeps a digitally silent
/// input (a muted or dead mic reports −160 dBFS) from setting a threshold
/// nothing can fall under and calling silence speech; the high one stops a
/// very loud room from setting a line no voice could clear.
const double minThresholdDb = -54;
const double maxThresholdDb = -24;

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
  return sorted[i];
}

/// The silence threshold for a window of level samples, oldest first.
/// Exported for what it is — the whole decision — so it can be checked
/// directly. Returns the fixed line for an empty window.
double thresholdFrom(List<double> levelsDb) {
  if (levelsDb.isEmpty) return fallbackThresholdDb;
  final sorted = [...levelsDb]..sort();
  // The 5th rather than the minimum: one dropped buffer or one sample caught
  // between two words should not become the room.
  final floor = _percentile(sorted, 0.05);
  final loud = _percentile(sorted, 0.9);
  final raw = loud >= floor + contrastDb
      ? (floor + voiceOverRoomDb < loud + speechClampDb ? floor + voiceOverRoomDb : loud + speechClampDb)
      : floor + voiceOverRoomDb;
  return raw.clamp(minThresholdDb, maxThresholdDb);
}

/// A rolling read of what silence sounds like in this room.
///
/// The policy pushes every metering sample it takes and asks for the
/// threshold on each one. The window is held by TIME rather than by count:
/// the native side reports every 100 ms of AUDIO, which under a paused
/// session or a late capture thread is not every 100 ms of wall clock.
class RoomMeter {
  final List<double> _levels = [];
  final List<int> _at = [];

  /// Forget everything: a new take is a new room.
  void reset() {
    _levels.clear();
    _at.clear();
  }

  void push(double db, int atMs) {
    _levels.add(db);
    _at.add(atMs);
    final cutoff = atMs - floorWindowMs;
    // The window is a queue, so one scan from the front is the whole eviction.
    var drop = 0;
    while (drop < _at.length && _at[drop] < cutoff) {
      drop++;
    }
    if (drop > 0) {
      _levels.removeRange(0, drop);
      _at.removeRange(0, drop);
    }
  }

  /// How much audio the window holds.
  int spanMs(int atMs) => _at.isEmpty ? 0 : atMs - _at.first;

  /// The level at or above which a sample counts as speech, right now.
  double threshold(int atMs) => spanMs(atMs) < warmupMs ? fallbackThresholdDb : thresholdFrom(_levels);
}
