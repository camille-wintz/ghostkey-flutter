import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/dictation/seam_ledger.dart';

void main() {
  test('consecutive chunks that meet exactly have no gap', () {
    final l = SeamLedger()
      ..add(index: 0, startFrame: 0, endFrame: 120)
      ..add(index: 1, startFrame: 120, endFrame: 400)
      ..add(index: 2, startFrame: 400, endFrame: 401);
    expect(l.gaps(), isEmpty);
    expect(l.framesCovered, 401);
    expect(l.covers(samplesIn: 401 * 1024 - 500, framesOut: 401), isTrue);
    expect(l.report(samplesIn: 401 * 1024 - 500, framesOut: 401), isNull);
  });

  test('a missing frame between two files is a positive gap', () {
    final l = SeamLedger()
      ..add(index: 0, startFrame: 0, endFrame: 100)
      ..add(index: 1, startFrame: 101, endFrame: 200);
    final gaps = l.gaps();
    expect(gaps, hasLength(1));
    expect(gaps.single.afterIndex, 0);
    expect(gaps.single.frames, 1);
    expect(l.report(samplesIn: 0, framesOut: 199), contains('1 gap'));
  });

  test('a doubled frame is a negative gap', () {
    final l = SeamLedger()
      ..add(index: 0, startFrame: 0, endFrame: 100)
      ..add(index: 1, startFrame: 99, endFrame: 200);
    expect(l.gaps().single.frames, -1);
  });

  test('chunks are checked in index order however they arrive', () {
    final l = SeamLedger()
      ..add(index: 1, startFrame: 50, endFrame: 80)
      ..add(index: 0, startFrame: 0, endFrame: 50);
    expect(l.gaps(), isEmpty);
  });

  test('coverage fails when the files do not account for every frame written', () {
    final l = SeamLedger()..add(index: 0, startFrame: 0, endFrame: 10);
    expect(l.covers(samplesIn: 10 * 1024, framesOut: 12), isFalse);
    expect(l.report(samplesIn: 10 * 1024, framesOut: 12), contains('coverage'));
  });

  test('coverage fails when fewer frames were written than samples fed', () {
    final l = SeamLedger()..add(index: 0, startFrame: 0, endFrame: 10);
    expect(l.covers(samplesIn: 11 * 1024, framesOut: 10), isFalse);
  });
}
