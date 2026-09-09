import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/dictation/policy.dart';

void main() {
  const loud = -10.0;
  const quiet = -60.0;

  /// Feed [ms] of audio at [db], 100 ms per tick, advancing the clock.
  PolicyDecision feed(SessionPolicy p, double db, int ms, int Function() clock) {
    PolicyDecision last = const KeepGoing();
    for (var t = 0; t < ms; t += DictationPolicy.pollIntervalMs) {
      last = p.onLevel(db: db, nowMs: clock());
      if (last is! KeepGoing) return last;
    }
    return last;
  }

  test('the constants are the RN policy, with the desktop hold', () {
    expect(DictationPolicy.silenceDbThreshold, -30);
    expect(DictationPolicy.silenceHoldMs, 1000);
    expect(DictationPolicy.minVoicedMs, 300);
    expect(DictationPolicy.pollIntervalMs, 100);
    expect(DictationPolicy.defaultMaxChunkMs, 600000);
    expect(DictationPolicy.silentChunkMs, 60000);
    expect(DictationPolicy.idleStopMs, 300000);
    expect(DictationPolicy.maxSessionMs, 3600000);
    expect(DictationPolicy.retryDelaysMs, [4000, 12000]);
    expect(DictationPolicy.uploadTimeoutMs, 120000);
    expect(DictationPolicy.sessionTurns, 4);
    expect(DictationPolicy.previousChars, 600);
  });

  test('speech then a one-second silence cuts the chunk', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy()..startSession(0);
    expect(feed(p, loud, 500, clock), isA<KeepGoing>());
    expect(p.chunkVoiced, isTrue);
    expect(feed(p, quiet, 900, clock), isA<KeepGoing>());
    final d = feed(p, quiet, 100, clock);
    expect(d, isA<CutChunk>());
    expect((d as CutChunk).reason, CutReason.silence);
  });

  test('silence does not arm before minVoicedMs of speech', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy()..startSession(0);
    feed(p, loud, 200, clock);
    expect(feed(p, quiet, 5000, clock), isA<KeepGoing>());
    expect(p.silenceMs, 0);
  });

  test('speech inside the hold resets it', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy()..startSession(0);
    feed(p, loud, 400, clock);
    feed(p, quiet, 800, clock);
    feed(p, loud, 100, clock);
    expect(p.silenceMs, 0);
    expect(feed(p, quiet, 900, clock), isA<KeepGoing>());
  });

  test('a chunk that never heard speech is cut at silentChunkMs', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy()..startSession(0);
    final d = feed(p, quiet, DictationPolicy.silentChunkMs + 100, clock);
    expect(d, isA<CutChunk>());
    expect((d as CutChunk).reason, CutReason.silentChunk);
    expect(p.chunkVoiced, isFalse);
  });

  test('unbroken speech is cut at the cap', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy(maxChunkMs: 5000)..startSession(0);
    final d = feed(p, loud, 6000, clock);
    expect(d, isA<CutChunk>());
    expect((d as CutChunk).reason, CutReason.cap);
  });

  test('idle stops after five minutes with nothing pending', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy()..startSession(0);
    // Room tone only: every sixty seconds the never-voiced chunk is cut and a
    // new one starts, until the idle clock runs out.
    PolicyDecision last = const KeepGoing();
    var cuts = 0;
    while (last is! EndSession) {
      last = feed(p, quiet, DictationPolicy.silentChunkMs + 100, clock);
      if (last is CutChunk) {
        expect(last.reason, CutReason.silentChunk);
        cuts += 1;
        p.startChunk(now);
      }
    }
    expect(last.reason, AutoStopReason.idle);
    expect(cuts, 4);
    expect(now, greaterThanOrEqualTo(DictationPolicy.idleStopMs));
  });

  test('idle never fires while a chunk is in flight', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy(maxChunkMs: 1 << 30)..startSession(0);
    p.pending = 1;
    feed(p, loud, 400, clock);
    // Loud throughout, so no silence cut and no silent-chunk cut.
    expect(feed(p, loud, DictationPolicy.idleStopMs + 1000, clock), isA<KeepGoing>());
  });

  test('speech counts as activity for the idle clock', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy(maxChunkMs: 1 << 30)..startSession(0);
    feed(p, loud, 400, clock);
    now = DictationPolicy.idleStopMs - 1000;
    p.noteActivity(now);
    expect(feed(p, loud, 3000, clock), isA<KeepGoing>());
  });

  test('the ceiling ends the session unconditionally', () {
    var now = 0;
    int clock() => now += 100;
    final p = SessionPolicy(maxChunkMs: 1 << 30)..startSession(0);
    p.pending = 3;
    now = DictationPolicy.maxSessionMs - 200;
    p.startChunk(now);
    final d = feed(p, loud, 500, clock);
    expect(d, isA<EndSession>());
    expect((d as EndSession).reason, AutoStopReason.ceiling);
  });

  test('normalizeDb maps the floor and ceiling to 0..1', () {
    expect(DictationPolicy.normalizeDb(-50), 0);
    expect(DictationPolicy.normalizeDb(0), 1);
    expect(DictationPolicy.normalizeDb(-25), 0.5);
    expect(DictationPolicy.normalizeDb(-160), 0);
    expect(DictationPolicy.normalizeDb(10), 1);
  });
}
