import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/dictation/erase_silence.dart';

const rate = 16000;

Int16List _concat(List<Int16List> parts) {
  final out = Int16List(parts.fold(0, (n, p) => n + p.length));
  var at = 0;
  for (final p in parts) {
    out.setRange(at, at + p.length, p);
    at += p.length;
  }
  return out;
}

/// Stationary noise at a fixed amplitude — a room, at any volume.
Int16List _room(int ms, int amplitude, [int seed = 1]) {
  final rnd = Random(seed);
  final n = ms * rate ~/ 1000;
  return Int16List.fromList([
    for (var i = 0; i < n; i++) (rnd.nextDouble() * 2 - 1) * amplitude ~/ 1,
  ]);
}

/// A pulse train at a speaking pitch under a syllabic envelope, with a little
/// breath on it. What separates speech from a room is that the level MOVES;
/// what separates it from a hand on the desk is that it has a PITCH — so the
/// fixture has to have both.
Int16List _speech(int ms, int amplitude, [int seed = 2]) {
  final rnd = Random(seed);
  final n = ms * rate ~/ 1000;
  const syllableMs = 80;
  const period = rate ~/ 120; // 120 Hz
  return Int16List.fromList([
    for (var i = 0; i < n; i++)
      (((i % period) / period * 2 - 1) * 0.9 + (rnd.nextDouble() * 2 - 1) * 0.1) *
          ((i ~/ (syllableMs * rate ~/ 1000)).isEven ? amplitude : amplitude ~/ 20) ~/
          1,
  ]);
}

/// The same syllabic envelope over noise with no pitch in it — a rustle, a
/// hand on the desk, cloth on the microphone.
Int16List _rustle(int ms, int amplitude, [int seed = 2]) {
  final rnd = Random(seed);
  final n = ms * rate ~/ 1000;
  const syllableMs = 80;
  return Int16List.fromList([
    for (var i = 0; i < n; i++)
      ((rnd.nextDouble() * 2 - 1) *
              ((i ~/ (syllableMs * rate ~/ 1000)).isEven ? amplitude : amplitude ~/ 20)) ~/
          1,
  ]);
}

/// A melody from across the room: one sawtooth line stepping through notes,
/// each note swelling and fading, over a quiet room. Pitched and modulated,
/// so it is a voice to every test that reads shape rather than level.
Int16List _music(int ms, int amplitude, [int seed = 5]) {
  final rnd = Random(seed);
  final n = ms * rate ~/ 1000;
  const noteMs = 250;
  const notes = [220.0, 247.0, 262.0, 294.0, 330.0, 294.0, 262.0, 196.0];
  final noteLen = noteMs * rate ~/ 1000;
  return Int16List.fromList([
    for (var i = 0; i < n; i++)
      (() {
        final hz = notes[(i ~/ noteLen) % notes.length];
        final phase = (i * hz / rate) % 1;
        final env = sin((i % noteLen) / noteLen * pi);
        return ((phase * 2 - 1) * env * amplitude + (rnd.nextDouble() * 2 - 1) * 120) ~/ 1;
      })(),
  ]);
}

/// The final chunk of a take when Done comes more than a second after the
/// last word: room, a hand reaching across the desk (low, swelling, uneven),
/// a click, room. Loud enough and uneven enough to pass every level gate.
Int16List _stopping() {
  final rnd = Random(4);
  final n = 1250 * rate ~/ 1000;
  final out = List<double>.generate(n, (_) => (rnd.nextDouble() * 2 - 1) * 130);
  final rumble = 600 * rate ~/ 1000;
  var lp = 0.0;
  for (var i = 0; i < rumble; i++) {
    lp = lp * 0.97 + (rnd.nextDouble() * 2 - 1) * 0.03;
    final env = pow(sin(i / rumble * pi), 2) * (0.8 + 0.2 * sin(i / 400));
    out[300 * rate ~/ 1000 + i] += lp * 1.2 * env * 32767;
  }
  for (final (at, amp) in [(880, 0.4), (960, 0.2)]) {
    for (var i = 0; i < 6 * rate ~/ 1000; i++) {
      out[at * rate ~/ 1000 + i] += (rnd.nextDouble() * 2 - 1) * amp * exp(-i / (1.5 * rate / 1000)) * 32767;
    }
  }
  return Int16List.fromList([for (final v in out) v.clamp(-32768, 32767).toInt()]);
}

void main() {
  test('room tone is dropped, however loud', () {
    for (final amplitude in [120, 900, 6000]) {
      final verdict = eraseSilence(_room(6000, amplitude), rate);
      expect(verdict.speech, isFalse, reason: 'amplitude $amplitude');
      // A chunk that turned out to be nothing but room is still the cleanest
      // reading of that room the session will get.
      expect(verdict.floor, greaterThan(0));
    }
  });

  test('digital silence is dropped', () {
    expect(eraseSilence(Int16List(6 * rate), rate).speech, isFalse);
  });

  test('audio too short to hold a word is dropped', () {
    expect(eraseSilence(_speech(200, 6000), rate).speech, isFalse);
    expect(eraseSilence(Int16List(0), rate).speech, isFalse);
    // …and the drop reports no reading, which is not a reading of silence.
    expect(eraseSilence(_speech(200, 6000), rate).floor, 0);
  });

  test('a pause between two sentences is cut down, not out', () {
    final chunk = _concat([_speech(1200, 6000), _room(3000, 120), _speech(1200, 6000)]);
    final verdict = eraseSilence(chunk, rate);
    expect(verdict.speech, isTrue);
    expect(verdict.wav, isNotNull);
    expect(verdict.removedMs, greaterThanOrEqualTo(minRemovedMs));
    // The pad either side and maxGapMs of the pause itself survive, so the
    // model still reads a sentence boundary there.
    expect(verdict.removedMs, lessThanOrEqualTo(3000 - 2 * padMs - maxGapMs + frameMs));
    expect(verdict.removedMs, greaterThanOrEqualTo(3000 - 2 * padMs - maxGapMs - 2 * frameMs));
  });

  test('speech end to end is sent as recorded', () {
    final verdict = eraseSilence(_speech(6000, 6000), rate);
    expect(verdict.speech, isTrue);
    expect(verdict.wav, isNull, reason: 'nothing worth rebuilding for');
    expect(verdict.removedMs, 0);
  });

  test('the lead-in and the tail are squeezed like any other pause, not cut out', () {
    final chunk = _concat([_room(2000, 120, 3), _speech(1500, 6000), _room(4000, 120)]);
    final verdict = eraseSilence(chunk, rate);
    expect(verdict.speech, isTrue);
    expect(verdict.wav, isNotNull);
    // Each edge keeps its pad plus maxGapMs; the rest of both goes.
    const expected = (2000 - padMs - maxGapMs) + (4000 - padMs - maxGapMs);
    expect(verdict.removedMs, inInclusiveRange(expected - 2 * frameMs, expected + 2 * frameMs));
    final sentMs = (verdict.wav!.length - 44) ~/ 2 * 1000 ~/ rate;
    expect(sentMs, greaterThanOrEqualTo(1500 + 2 * (padMs + maxGapMs) - 2 * frameMs));
  });

  test('a hand reaching for the phone, and the tap, are dropped', () {
    final verdict = eraseSilence(_stopping(), rate, sessionFloor: 0.004);
    expect(verdict.speech, isFalse);
    // …and with no session floor to compare to, since the two level tests
    // cannot tell it from a voice and the pitch test does not need the room.
    expect(eraseSilence(_stopping(), rate).speech, isFalse);
  });

  test('noise under a syllabic envelope is not a voice', () {
    expect(eraseSilence(_rustle(4000, 6000), rate).speech, isFalse);
  });

  test('a quiet voice that does not clear the room is dropped', () {
    // Modulated and pitched, so the movement and voice tests pass it — but
    // its loudest moments are barely over a room measured across the rest
    // of the take.
    final verdict = eraseSilence(_speech(4000, 200), rate, sessionFloor: 0.05);
    expect(verdict.speech, isFalse);
    // The same audio with no session floor to compare to is kept: a chunk
    // cannot answer this question about itself.
    expect(eraseSilence(_speech(4000, 200), rate).speech, isTrue);
  });

  test('music in the room is dropped once the author has spoken', () {
    final author = eraseSilence(_speech(4000, 6000), rate);
    expect(author.speech, isTrue);
    expect(author.voice, greaterThan(0));
    // Pitched, moving and above the room: every shape test passes it…
    expect(eraseSilence(_music(4000, 1500), rate, sessionFloor: 0.004).speech, isTrue);
    // …and only its level, against the author's, gives it away.
    final music = eraseSilence(_music(4000, 1500), rate, sessionFloor: 0.004, sessionVoice: author.voice);
    expect(music.speech, isFalse);
    expect(music.voice, 0, reason: 'a dropped chunk is no reading of the voice');
  });

  test('the author a little quieter than they started is still the author', () {
    final author = eraseSilence(_speech(4000, 6000), rate);
    final softer = eraseSilence(_speech(4000, 3000, 7), rate, sessionFloor: 0.004, sessionVoice: author.voice);
    expect(softer.speech, isTrue);
  });

  test('a chunk recorded above 16 kHz is decimated, not refused', () {
    final at48k = _concat([
      _speech(1200, 6000).let48k(),
      _room(3000, 120).let48k(),
      _speech(1200, 6000).let48k(),
    ]);
    final verdict = eraseSilence(at48k, 48000);
    expect(verdict.speech, isTrue);
    expect(verdict.wav, isNotNull);
    // Rebuilt at the speech rate whatever came in.
    final view = ByteData.view(verdict.wav!.buffer);
    expect(view.getUint32(24, Endian.little), targetRate);
  });

  test('encodeWav writes a mono 16 kHz PCM header', () {
    final wav = encodeWav(Int16List.fromList([0, 1, -1, 32767]), targetRate);
    final view = ByteData.view(wav.buffer);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(view.getUint16(20, Endian.little), 1); // PCM
    expect(view.getUint16(22, Endian.little), 1); // mono
    expect(view.getUint32(24, Endian.little), targetRate);
    expect(view.getUint16(34, Endian.little), 16); // bits
    expect(view.getUint32(40, Endian.little), 8); // 4 samples
    expect(wav.length, 44 + 8);
    expect(view.getInt16(44 + 6, Endian.little), 32767);
  });

  group('sessionVoiceOf', () {
    test('is null until a chunk has held a voice', () {
      expect(sessionVoiceOf([]), isNull);
      expect(sessionVoiceOf([0, 0]), isNull);
    });

    test('a take that opens on the music corrects itself when the author speaks', () {
      expect(sessionVoiceOf([0.01, 0.08]), 0.08);
    });

    test('is the median of the first few, and then holds', () {
      expect(sessionVoiceOf([0.06, 0.01, 0.08]), 0.06);
      expect(sessionVoiceOf([0.06, 0.01, 0.08, 0.001, 0.001, 0.001]), 0.06);
    });
  });

  group('sessionFloorOf', () {
    test('is null until something has been measured', () {
      expect(sessionFloorOf([]), isNull);
      expect(sessionFloorOf([0, 0]), isNull);
    });

    test('is the quietest reading, not the average', () {
      expect(sessionFloorOf([0.02, 0.004, 0.03]), 0.004);
    });

    test('only remembers the last few, so the room can rise', () {
      final quietThenLoud = [0.001, for (var i = 0; i < sessionFloorChunks; i++) 0.02];
      expect(sessionFloorOf(quietThenLoud), 0.02);
    });
  });
}

extension on Int16List {
  /// The same audio sampled three times as often — a phone whose AudioRecord
  /// refused 16 kHz.
  Int16List let48k() {
    final out = Int16List(length * 3);
    for (var i = 0; i < length; i++) {
      out[i * 3] = this[i];
      out[i * 3 + 1] = this[i];
      out[i * 3 + 2] = this[i];
    }
    return out;
  }
}
