// Cut the silence out of a dictation chunk before it is sent to be
// transcribed. Ported from ghost-key `src/shared/audio/eraseSilence.ts`,
// constant for constant; that file's header carries the measurements and is
// the one to read before changing a number here.
//
// WHY, and it is not bandwidth. `gemini-3.8-flash` invents words over
// non-speech: fed six seconds of room tone it returns a fluent sentence, and
// no instruction, temperature or thinking budget stops it (server
// `scripts/dictation-gemini-harness.mts`). The invention lands in its
// `verbatim` transcript as well as its cleaned one, so the server's
// faithfulness gate aligns the two, finds them in agreement, and passes
// prose the writer never spoke straight into the manuscript. Nothing
// downstream can see it — and on this client nothing downstream can see it
// either, because dictation here writes into the document with no Apply
// button in front of it. What CAN see it is this side, before the audio is
// sent: audio the model never hears is audio it cannot invent over.
//
// The session already drops a chunk that never heard speech (`chunkVoiced`
// in policy.dart), and that gate is per-CHUNK: a chunk qualifies on 300 ms
// of speech and everything else in it still goes up — the silence hold at
// the end, the pauses a writer takes mid-thought, the tail before somebody
// reached for Done. So this pass asks two questions the chunk gate cannot:
//
//   1. Is anyone speaking? Two tests, and either one answering no drops the
//      chunk. How much the level MOVES, not how high it is — speech is
//      modulated by syllables, a room is stationary at any volume (see
//      [modulationMin]). And whether anything in the chunk rises above the
//      ROOM, which is the one question a chunk holding no speech cannot
//      answer about itself: its own quietest frames ARE the room, so
//      measured alone it always looks like it has a floor and something
//      above it. That is what [sessionFloorOf] is for.
//   2. Which parts are speech? Answered per REGION against the chunk's own
//      measured floor, so what survives is what stood above this room rather
//      than above a number chosen on someone else's microphone.
//
// THE TWO FLOORS ARE DIFFERENT MEASUREMENTS AND DO DIFFERENT JOBS. The
// chunk's own floor describes the background present in THIS audio, which is
// what the erasure threshold has to be set from. The session floor describes
// the room when nobody is talking, gathered across the take, and it is what
// "is anyone speaking" has to be asked against. Using either for the other's
// job is wrong in a way that shows: threshold the session floor and a chunk
// that is 90% loud noise keeps all of it; judge speech by the chunk's own
// floor and a chunk that is nothing BUT noise passes, because noise is
// reliably louder than its own quietest moment.
//
// Conservative on purpose, because the two mistakes do not cost the same. A
// stretch of noise left in risks an invented sentence; a syllable erased is a
// word missing from the writer's own dictation. So every judgment ABOUT THE
// AUDIO fails towards keeping it: a chunk whose speech does not stand clear
// of its own floor is passed through untouched, gaps are SHORTENED rather
// than removed, and a result that came out too big is sent as recorded.
//
// The one class of judgment that fails the OTHER way is audio this pass
// could not read at all — a file the decoder refuses, or one too short to
// hold a word. Measured on the desktop 2026-09-12: the model invents over
// such a payload 30 runs of 30 and never once returns empty, while a
// truncated clip of real speech did NOT come back as those words. So the
// model cannot read what the decoder could not either, passing it through
// buys nothing to set against the invention, and unreadable audio holds no
// words to protect. If it cannot be read, it is dropped.

import 'dart:math' as math;
import 'dart:typed_data';

/// 20 ms of audio per measurement — short enough to land a gap between
/// words, long enough that one glottal pulse is not a region of its own.
const int frameMs = 20;

/// Everything is measured and rebuilt at speech-recognition rate. The
/// recorder asks AudioRecord for this rate and gets it on every phone that
/// has been tried; a device that falls back to 44.1 or 48 kHz is decimated
/// here, which is also what keeps the uncompressed result worth uploading.
const int targetRate = 16000;

/// Kept either side of a speech region. A word's first consonant and its
/// last breath are below any level threshold, and clipping them is exactly
/// the "erased a syllable" failure this pass must not cause.
const int padMs = 250;

/// The longest silence left of any pause, beyond the [padMs] either side of
/// the speech — including the lead-in before the first word and the tail
/// after the last. Squeezed, never removed: a pause is a sentence boundary
/// the model reads, and with the pauses cut down harder than this (and the
/// chunk's edges cut out) dictation on the phone came back as one run of
/// comma-spliced clauses with no sentence ever ending (Cleo, 2026-09-12).
const int maxGapMs = 500;

/// How far speech must stand above the chunk's own noise floor before this
/// pass will erase anything at all — about 12 dB. Under that, floor and
/// speech are not separable and the safe answer is to cut nothing. This
/// answers "can I cut cleanly", NOT "is anyone speaking".
const double minSnr = 4;

/// What DOES answer it: how much the level moves, as the coefficient of
/// variation of the frame levels. Measured on the desktop, the two classes
/// separate with room to spare — a loud low rumble reads 0.127, speech
/// buried in a loud white floor reads 0.44. Under this line a chunk is
/// DROPPED, so a wrong answer here costs the writer words.
const double modulationMin = 0.25;

/// How far the chunk's loudest moments must stand above the ROOM before it
/// counts as holding speech. Lower than [minSnr] on purpose — the two tests
/// face opposite ways. Failing [minSnr] only means "do not cut here";
/// failing this one DROPS the chunk, and an author sitting back from the
/// phone must not lose their words to it.
const double roomSnr = 2.5;

/// Silence is anything within ~6 dB of the floor…
const double floorMultiple = 2;

/// …but never anything within 12 dB of the speech level, whatever the floor
/// says. The clamp that stops a chunk with an unusually loud floor from
/// setting a threshold that eats quiet speech.
const double speechFraction = 0.25;

/// How many recent chunks the session floor is taken from.
const int sessionFloorChunks = 8;

/// Less kept audio than this and there was no speech here — the same floor
/// the chunk gate uses, applied to what survived rather than to what was
/// recorded.
const int minKeptMs = 300;

/// …and the same floor applied to what was RECORDED, read off the decoded
/// audio rather than off the file's size. A chunk shorter than the policy's
/// own `minVoicedMs` cannot hold the speech that gate says it holds.
/// Duration rather than bytes because bytes do not say: an `.m4a` header
/// with no audio in it carries no audio at all.
const int minAudioMs = 300;

/// Below this much removed, rebuilding is not worth an uncompressed upload:
/// the chunk was already speech end to end.
const int minRemovedMs = 500;

/// A rebuilt chunk over this is not sent — the server's inline-audio ceiling
/// is 11 MB and WAV at 16 kHz is ~32 KB/s, so this is ~5 minutes of
/// surviving speech. Past it the original AAC (~8x smaller) goes instead.
const int maxWavBytes = 9 * 1024 * 1024;

/// What [eraseSilence] decided about one chunk.
class Erasure {
  const Erasure({required this.speech, this.wav, this.removedMs = 0, this.floor = 0});

  /// False when nothing in the chunk stood above its own noise floor, or the
  /// audio could not be read at all: there is nothing here to transcribe and
  /// the caller drops the chunk rather than sending it.
  final bool speech;

  /// The rebuilt WAV to send, or null when this pass decided to change
  /// nothing and the recorded file should go as it is.
  final Uint8List? wav;

  /// Milliseconds of audio removed — 0 when the chunk was passed through.
  final int removedMs;

  /// This chunk's own measured noise floor, for the caller to pool into the
  /// session estimate it passes back in ([sessionFloorOf]). Reported for
  /// every chunk INCLUDING a dropped one — a chunk that turned out to be
  /// nothing but room is the cleanest reading of that room anyone is going
  /// to get. 0 when the chunk could not be analysed, which is not the same
  /// as a reading of silence.
  final double floor;
}

/// Remove the stretches of a dictation chunk that hold no speech.
///
/// [samples] is 16-bit mono PCM as the decoder handed it over, [sampleRate]
/// its rate. [sessionFloor] is the room's level when nobody is speaking,
/// measured across this session's recent chunks; omit it on the first chunk
/// of a take, where the chunk is judged on its own — which is all this pass
/// could ever do before.
///
/// Never throws. `speech: false` is the verdict to act on.
Erasure eraseSilence(Int16List samples, int sampleRate, {double? sessionFloor}) {
  const unreadable = Erasure(speech: false);

  final rate = sampleRate > targetRate ? targetRate : sampleRate;
  final pcm = rate == sampleRate ? samples : _decimate(samples, sampleRate, rate);
  if (pcm.length < minAudioMs * rate ~/ 1000) return unreadable;

  final frameLen = frameMs * rate ~/ 1000;
  final levels = <double>[];
  for (var i = 0; i + frameLen <= pcm.length; i += frameLen) {
    levels.add(_rms(pcm, i, i + frameLen));
  }
  if (levels.length < 3) return unreadable;

  // Is anyone speaking at all? Asked of the level's MOVEMENT, not its
  // height, because height is what the chunk gate already tested and what a
  // loud room defeats. Nothing stationary is speech, at any volume.
  final mean = levels.reduce((a, b) => a + b) / levels.length;
  final spread = math.sqrt(
    levels.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) / levels.length,
  );
  final sorted = [...levels]..sort();
  final floor = _percentile(sorted, 0.1);
  if (mean <= 0 || spread / mean < modulationMin) {
    return Erasure(speech: false, floor: floor);
  }

  final speechLevel = _percentile(sorted, 0.9);

  // The second speech test, and the one a chunk cannot run on itself: does
  // anything here rise above the ROOM? A chunk of nothing but background
  // does not — its loudest moments are the same background as its quietest.
  //
  // What it catches that the modulation test does not is non-speech sitting
  // AT room level that happens to fluctuate. What neither catches is
  // fluctuating noise that is LOUD — a door, cutlery, a chair — which clears
  // the room easily and reads as modulated. Separating that from a voice
  // needs spectral structure, not levels, and is not attempted here.
  if (sessionFloor != null && sessionFloor > 0 && speechLevel < sessionFloor * roomSnr) {
    return Erasure(speech: false, floor: floor);
  }

  // There is speech; this is the separate question of whether it stands
  // clear enough of THIS chunk's own background to cut around without
  // clipping it. When it does not, the chunk goes as recorded — with the
  // silence still in it, which is worse than erasing it and much better than
  // erasing a syllable.
  if (speechLevel < floor * minSnr) return Erasure(speech: true, floor: floor);

  final threshold = math.min(floor * floorMultiple, speechLevel * speechFraction);
  final padFrames = (padMs / frameMs).ceil();
  // Widen each speech region by the pad before anything is cut, so the pad
  // is measured from the speech rather than from the last surviving frame.
  final loud = [for (final l in levels) l >= threshold];
  final keep = List<bool>.generate(levels.length, (i) {
    final from = math.max(0, i - padFrames);
    final to = math.min(loud.length, i + padFrames + 1);
    for (var j = from; j < to; j++) {
      if (loud[j]) return true;
    }
    return false;
  });

  if (keep.where((k) => k).length * frameMs < minKeptMs) {
    return Erasure(speech: false, floor: floor);
  }

  // Walk the frames and copy: every kept frame, and at most [maxGapMs] of
  // each silent run — between two regions and at either end alike. A lead-in
  // keeps the frames nearest the first word, everything else the frames
  // nearest the speech before it.
  final maxGapFrames = (maxGapMs / frameMs).ceil();
  final out = <int>[];
  var removedFrames = 0;
  var i = 0;
  while (i < keep.length) {
    if (keep[i]) {
      out.add(i);
      i++;
      continue;
    }
    var end = i;
    while (end < keep.length && !keep[end]) {
      end++;
    }
    final run = end - i;
    final kept = math.min(run, maxGapFrames);
    final from = i == 0 ? end - kept : i;
    for (var j = 0; j < kept; j++) {
      out.add(from + j);
    }
    removedFrames += run - kept;
    i = end;
  }

  final removedMs = removedFrames * frameMs;
  if (removedMs < minRemovedMs) return Erasure(speech: true, floor: floor);

  final rebuilt = Int16List(out.length * frameLen);
  for (var n = 0; n < out.length; n++) {
    rebuilt.setRange(n * frameLen, (n + 1) * frameLen, pcm, out[n] * frameLen);
  }
  final wav = encodeWav(rebuilt, rate);
  if (wav.length > maxWavBytes) return Erasure(speech: true, floor: floor);
  return Erasure(speech: true, wav: wav, removedMs: removedMs, floor: floor);
}

/// The session's noise floor from the chunk floors seen so far: the quietest
/// of the last [sessionFloorChunks], or null while there are none (the first
/// chunk of a take, which is judged on itself).
///
/// The quietest rather than an average because the readings are not samples
/// of one quantity — a chunk of unbroken speech reports a floor made of
/// speech, and averaging that in pulls the room upwards until real speech
/// stops clearing it. Every reading is an upper bound on the room; the
/// lowest is the closest to it.
double? sessionFloorOf(List<double> floors) {
  final recent = floors.where((f) => f > 0).toList();
  if (recent.isEmpty) return null;
  final window = recent.length > sessionFloorChunks ? recent.sublist(recent.length - sessionFloorChunks) : recent;
  return window.reduce(math.min);
}

/// Mono 16-bit PCM in a WAV container. Uncompressed on purpose: the point is
/// to hand the model audio it can transcribe, and nothing here re-encodes to
/// AAC without running the encoder again.
Uint8List encodeWav(Int16List samples, int rate) {
  final dataBytes = samples.length * 2;
  final out = Uint8List(44 + dataBytes);
  final view = ByteData.view(out.buffer);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      out[at + i] = s.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVEfmt ');
  view.setUint32(16, 16, Endian.little); // PCM header length
  view.setUint16(20, 1, Endian.little); // PCM
  view.setUint16(22, 1, Endian.little); // mono
  view.setUint32(24, rate, Endian.little);
  view.setUint32(28, rate * 2, Endian.little); // byte rate
  view.setUint16(32, 2, Endian.little); // block align
  view.setUint16(34, 16, Endian.little); // bits
  ascii(36, 'data');
  view.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return out;
}

/// Root mean square of one frame, as linear amplitude 0..1 — the units the
/// desktop's analyser meters in, so the constants above are the same
/// numbers on both clients.
double _rms(Int16List samples, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to; i++) {
    final s = samples[i] / 32768.0;
    sum += s * s;
  }
  return math.sqrt(sum / math.max(1, to - from));
}

/// The value at [p] through a sorted copy — the noise floor and the speech
/// level are read as percentiles rather than min and max so that one clipped
/// sample or one unusually dead frame cannot set either.
double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
  return sorted[i];
}

/// Down to [to] Hz by averaging each output sample's span of input. Crude,
/// and the averaging is the only anti-aliasing there is — good enough for a
/// path that only runs when AudioRecord refused 16 kHz, which no phone
/// tried so far has done.
Int16List _decimate(Int16List input, int from, int to) {
  final n = input.length * to ~/ from;
  final out = Int16List(n);
  final step = from / to;
  for (var i = 0; i < n; i++) {
    final start = (i * step).floor();
    final end = math.min(input.length, math.max(start + 1, ((i + 1) * step).floor()));
    var sum = 0;
    for (var j = start; j < end; j++) {
      sum += input[j];
    }
    out[i] = sum ~/ (end - start);
  }
  return out;
}
