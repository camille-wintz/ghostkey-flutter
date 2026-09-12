import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/dictation/policy.dart';
import 'package:ghostkey/dictation/room_meter.dart';

void main() {
  /// A window of [ms] at [db], sampled at the recorder's cadence.
  List<double> room(double db, int ms) =>
      List.filled(ms ~/ DictationPolicy.pollIntervalMs, db);

  test('an empty window answers with the fixed line', () {
    expect(thresholdFrom([]), fallbackThresholdDb);
    expect(fallbackThresholdDb, DictationPolicy.silenceDbThreshold);
  });

  test('the warm-up holds the fixed line', () {
    final m = RoomMeter();
    var at = 0;
    for (var i = 0; i < 20; i++) {
      m.push(-70, at);
      at += 100;
    }
    expect(m.spanMs(at), lessThan(warmupMs));
    expect(m.threshold(at), fallbackThresholdDb);
  });

  test('a room louder than the old line stops reading as speech', () {
    // −28 dBFS of fan: every sample cleared the fixed −30, so the silence
    // hold never armed and chunks ran to the ten-minute cap.
    const fan = -28.0;
    expect(fan, greaterThan(DictationPolicy.silenceDbThreshold));
    expect(thresholdFrom(room(fan, 30000)), greaterThan(fan));
  });

  test('a voice quieter than the old line still counts as speech', () {
    // A soft author at −42: under the fixed −30 no sample was ever voiced
    // and the chunk was discarded unsent.
    const voice = -42.0;
    const quiet = -55.0;
    final levels = [...room(quiet, 20000), ...room(voice, 10000)];
    final t = thresholdFrom(levels);
    expect(voice, lessThan(DictationPolicy.silenceDbThreshold));
    expect(voice, greaterThanOrEqualTo(t));
    expect(quiet, lessThan(t));
  });

  test('a window of nothing but speech cannot walk the line into the speech', () {
    // No contrast, so the speech clamp is meaningless and the floor alone
    // sets the line — which stays under the speech that made the window.
    const speech = -20.0;
    expect(thresholdFrom(room(speech, 30000)), lessThanOrEqualTo(speech));
  });

  test('the answer stays inside its floor and ceiling', () {
    for (final db in [-160.0, -120.0, -60.0, -30.0, -6.0, 0.0]) {
      final t = thresholdFrom(room(db, 30000));
      expect(t, greaterThanOrEqualTo(minThresholdDb));
      expect(t, lessThanOrEqualTo(maxThresholdDb));
    }
  });

  test('a dead mic does not turn digital silence into speech', () {
    expect(thresholdFrom(room(-160, 30000)), greaterThan(-160));
  });

  test('the window is held by time, and follows a room that changes', () {
    final m = RoomMeter();
    var at = 0;
    void feed(double db, int ms) {
      for (var i = 0; i < ms ~/ 100; i++) {
        m.push(db, at);
        at += 100;
      }
    }

    feed(-70, 40000);
    final quiet = m.threshold(at);
    // A fan starts. Once it has filled the window, the old quiet is gone.
    feed(-28, floorWindowMs + 1000);
    expect(m.threshold(at), greaterThan(quiet));
    expect(m.spanMs(at), lessThanOrEqualTo(floorWindowMs + 100));
  });

  test('reset forgets the room', () {
    final m = RoomMeter();
    for (var i = 0; i < 400; i++) {
      m.push(-70, i * 100);
    }
    m.reset();
    expect(m.spanMs(40000), 0);
    expect(m.threshold(40000), fallbackThresholdDb);
  });
}
