import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/chapter_title.dart';
import 'package:ghostkey/core/pacing_wave.dart';

void main() {
  group('wavePoints', () {
    test('spreads chapters across the box, high intensity at the top', () {
      final points = wavePoints([0, 10, 5], const Size(124, 124), pad: 12);
      expect(points.map((p) => p.dx), [12, 62, 112]);
      expect(points.map((p) => p.dy), [112, 12, 62]);
    });

    test('centres a single chapter and clamps out-of-range values', () {
      final points = wavePoints([14], const Size(100, 100), pad: 10);
      expect(points.single, const Offset(50, 10));
    });
  });

  group('chapterTitle', () {
    test('drops the number prefix and the extension', () {
      final t = chapterTitle('03 - The Long Night.md', 2);
      expect(t.label, 'Chapter 3');
      expect(t.title, 'The Long Night');
      expect(t.source, '03 - The Long Night');
    });

    test('a bare numbered chapter has no title of its own', () {
      expect(chapterTitle('Chapter 12.md', 11).title, isNull);
    });

    test('chapterLabel keeps everything but the extension', () {
      expect(chapterLabel('1. Opening.MD'), '1. Opening');
    });
  });
}
