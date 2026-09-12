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

/// Noise under a syllabic envelope — what separates speech from a room is
/// that the level MOVES, so that is what the fixture has to have.
Int16List _speech(int ms, int amplitude, [int seed = 2]) {
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

  test('a rustle that does not clear the room is dropped', () {
    // Modulated, so the movement test passes it — but its loudest moments
    // are barely over a room measured across the rest of the take.
    final verdict = eraseSilence(_speech(4000, 200), rate, sessionFloor: 0.05);
    expect(verdict.speech, isFalse);
    // The same audio with no session floor to compare to is kept: a chunk
    // cannot answer this question about itself.
    expect(eraseSilence(_speech(4000, 200), rate).speech, isTrue);
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
