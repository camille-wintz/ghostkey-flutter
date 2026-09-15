import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/dictation/voicing.dart';

const rate = 16000;

Int16List _tone(int ms, int hz, {double amplitude = 8000}) {
  final period = rate / hz;
  return Int16List.fromList([
    for (var i = 0; i < ms * rate ~/ 1000; i++) (((i % period) / period * 2 - 1) * amplitude).toInt(),
  ]);
}

Int16List _noise(int ms, {double amplitude = 8000, int seed = 1}) {
  final rnd = Random(seed);
  return Int16List.fromList([
    for (var i = 0; i < ms * rate ~/ 1000; i++) ((rnd.nextDouble() * 2 - 1) * amplitude).toInt(),
  ]);
}

void main() {
  test('a pulse train anywhere in the speaking band is pitched', () {
    for (final hz in [80, 120, 220, 380]) {
      expect(isPitched(_tone(200, hz), rate, 0), isTrue, reason: '$hz Hz');
    }
  });

  test('noise, silence and a tone below the band are not', () {
    expect(isPitched(_noise(200), rate, 0), isFalse);
    expect(isPitched(Int16List(rate ~/ 5), rate, 0), isFalse);
    // A 50 Hz mains fundamental: its period is longer than any lag judged.
    expect(isPitched(_tone(200, 50), rate, 0), isFalse);
  });

  test('a frame near the end is judged against the audio before it', () {
    final tone = _tone(200, 120);
    expect(isPitched(tone, rate, tone.length - 10), isTrue);
    // …and audio shorter than one window plus one lag cannot be judged.
    expect(isPitched(_tone(30, 120), rate, 0), isFalse);
  });

  test('pitchedMs counts only the frames it is asked about and stops early', () {
    final chunk = _tone(2000, 120);
    final all = List<bool>.filled(100, true);
    expect(pitchedMs(chunk, rate, 20, all), minPitchedMs);
    final none = List<bool>.filled(100, false);
    expect(pitchedMs(chunk, rate, 20, none), 0);
    final two = [for (var i = 0; i < 100; i++) i < 2];
    expect(pitchedMs(chunk, rate, 20, two), 40);
  });

  test('a long chunk is sampled across its length, not read from the start', () {
    // Noise for 40 s, then a voice: more frames than maxJudgedFrames, and
    // the voice is only found if the judged frames are spread out.
    final noise = _noise(40000);
    final voice = _tone(2000, 120);
    final chunk = Int16List(noise.length + voice.length)
      ..setRange(0, noise.length, noise)
      ..setRange(noise.length, noise.length + voice.length, voice);
    final frames = chunk.length ~/ (20 * rate ~/ 1000);
    expect(pitchedMs(chunk, rate, 20, List<bool>.filled(frames, true)), greaterThanOrEqualTo(minPitchedMs));
  });
}
