import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/scan/viewfinder_geometry.dart';

void main() {
  group('coverRect', () {
    test('a preview taller than the box overflows top and bottom', () {
      // Box 300 × 400, preview 3:4 held as 1080 × 1920 (9:16): width fills.
      final rect = coverRect(const Size(300, 400), const Size(1080, 1920));
      expect(rect.width, closeTo(300, 1e-9));
      expect(rect.height, closeTo(533.33, 0.01));
      expect(rect.left, 0);
      expect(rect.top, closeTo(-66.67, 0.01));
    });

    test('a preview wider than the box overflows the sides', () {
      final rect = coverRect(const Size(300, 600), const Size(300, 400));
      expect(rect.height, 600);
      expect(rect.width, 450);
      expect(rect.left, -75);
    });

    test('a degenerate preview falls back to the box', () {
      expect(coverRect(const Size(300, 400), Size.zero), const Rect.fromLTWH(0, 0, 300, 400));
    });
  });

  group('normalizeIn', () {
    test('maps the centre of the drawn preview to (0.5, 0.5)', () {
      final rect = coverRect(const Size(300, 400), const Size(1080, 1920));
      expect(normalizeIn(rect, const Offset(150, 200)), const Offset(0.5, 0.5));
    });

    test('a tap in the box is offset by the crop', () {
      // Preview overflows 66.67 above the box: the box's top edge is 66.67
      // into a 533.33-tall preview → 0.125.
      final rect = coverRect(const Size(300, 400), const Size(1080, 1920));
      final point = normalizeIn(rect, const Offset(0, 0))!;
      expect(point.dx, 0);
      expect(point.dy, closeTo(0.125, 1e-6));
    });

    test('outside the drawn preview is null', () {
      final rect = coverRect(const Size(300, 600), const Size(300, 400));
      expect(normalizeIn(rect, const Offset(-80, 10)), isNull);
      expect(normalizeIn(rect, const Offset(10, 601)), isNull);
    });
  });
}
