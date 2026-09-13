// Is there a VOICE in this audio? Answered by periodicity, which is the one
// property of speech the level gates in erase_silence.dart cannot read.
// Ported from ghost-key `src/shared/audio/voicing.ts`, constant for constant;
// that file's header carries the measurements and is the one to read before
// changing a number here.
//
// The short version: the erasure's two speech tests measure how much the
// level moves and how far it stands above the room, and a hand reaching for
// the phone passes both — measured on the desktop 2026-09-13, room tone plus
// 600 ms of desk rumble plus a click went up as a one-second WAV and came
// back from the model as a couple of words, three runs of three. That is the
// final chunk of a take when Done is pressed more than a second after the
// last word: the hold has already cut the speech, and the take that becomes
// the last chunk hears nothing but the writer stopping. A voice is PERIODIC
// — vowels are a glottal pulse train at 70–400 Hz — and rumble, clicks and
// room tone are not periodic in that band at all. YIN's normalised
// difference dips to 0.001–0.008 on speech frames and never below 0.44 on
// the noise clips; the line is 0.2.
//
// A DROP gate, so it errs towards the writer: only frames already above the
// erasure threshold are judged, a chunk needs just [minPitchedMs] of them,
// and the count stops the moment it gets there.

import 'dart:typed_data';

/// The pitch band judged, in Hz. Wider than any speaking voice on purpose,
/// and stopping at 70 keeps a 50/60 Hz mains hum's fundamental out.
const int pitchMinHz = 70;
const int pitchMaxHz = 400;

/// Audio compared per frame. Longer than the erasure's 20 ms frame because
/// the difference function needs at least a period of the lowest pitch on
/// both sides of the lag; the window starts at the frame and runs into the
/// next one.
const int pitchWindowMs = 25;

/// YIN's cumulative-mean-normalised difference at the best lag, under which
/// a frame counts as pitched — the classic line. Speech fixtures sit at
/// 0.001–0.008 and the noise clips never under 0.44; Cleo's call
/// (2026-09-13) is that a dropped whisper is acceptable and an invented word
/// is not, so the gate is tuned towards the drop.
const double pitchThreshold = 0.15;

/// Pitched audio a chunk must hold to count as a voice. Ten 20 ms frames: a
/// word with a real vowel in it. The noise this exists for measures zero, so
/// the count is the margin against something quasi-periodic dipping under
/// the line for a frame or two; a very short one-syllable chunk may fall
/// under it, and per the tradeoff above that is the side to fall on.
const int minPitchedMs = 200;

/// The most frames judged in one chunk, spread evenly across it, so the
/// unpitched case — a ten-minute cap cut of fluctuating noise — costs a
/// fraction of a second rather than seconds on the UI isolate.
const int maxJudgedFrames = 1500;

/// Whether the window starting at [start] holds a periodic signal in the
/// pitch band: YIN steps 1–3 (difference function, cumulative-mean
/// normalisation, absolute threshold), stopping at the first lag under the
/// line — the question is "is there a pitch", not "which".
///
/// [start] is clamped so the last frames of a chunk are judged against the
/// audio before them rather than skipped.
bool isPitched(Int16List samples, int rate, int start) {
  final window = (pitchWindowMs * rate / 1000).round();
  final minLag = rate ~/ pitchMaxHz;
  final maxLag = (rate / pitchMinHz).ceil();
  final at = start < samples.length - window - maxLag ? start : samples.length - window - maxLag;
  if (at < 0) return false;
  var energy = 0.0;
  for (var n = 0; n < window; n++) {
    final s = samples[at + n].toDouble();
    energy += s * s;
  }
  if (energy <= 0) return false;

  var running = 0.0;
  for (var lag = 1; lag <= maxLag; lag++) {
    var d = 0.0;
    for (var n = 0; n < window; n++) {
      final v = (samples[at + n] - samples[at + n + lag]).toDouble();
      d += v * v;
    }
    running += d;
    if (lag >= minLag && running > 0 && (d * lag) / running < pitchThreshold) return true;
  }
  return false;
}

/// Milliseconds of pitched audio among the frames [judge] marks true, where
/// frame `i` is the [frameMs] starting at `i * frameMs`. Returns as soon as
/// [minPitchedMs] is reached, so the answer is "at least this much".
///
/// When more than [maxJudgedFrames] frames are marked, every k-th one is
/// judged — a long chunk is sampled across its whole length rather than only
/// at its start. A judged frame still counts for itself alone: one frame
/// standing in for twenty would let a single false positive pass a
/// ten-minute chunk of noise, and speech is dense enough with pitched frames
/// that sampling it costs nothing.
int pitchedMs(Int16List samples, int rate, int frameMs, List<bool> judge) {
  final marked = [
    for (var i = 0; i < judge.length; i++)
      if (judge[i]) i,
  ];
  final stride = marked.length > maxJudgedFrames ? (marked.length / maxJudgedFrames).ceil() : 1;
  final frameLen = frameMs * rate ~/ 1000;
  var ms = 0;
  for (var k = 0; k < marked.length && ms < minPitchedMs; k += stride) {
    if (isPitched(samples, rate, marked[k] * frameLen)) ms += frameMs;
  }
  return ms;
}
