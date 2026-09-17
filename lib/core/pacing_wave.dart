import 'dart:math' as math;
import 'dart:ui';

// The pacing curve's geometry, pure: one point per chapter, high for tension
// or action, low for a lull. The desk's `wisp/tasks/analyses/wave.ts`, so the
// two draw the same wave.

/// Intensities (0–10) placed left to right in a box, `pad` clear on every side.
List<Offset> wavePoints(List<double> values, Size box, {double pad = 12}) {
  final span = math.max(values.length - 1, 1);
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        values.length == 1 ? box.width / 2 : pad + (i / span) * (box.width - pad * 2),
        pad + (1 - values[i].clamp(0, 10) / 10) * (box.height - pad * 2),
      ),
  ];
}

/// A Catmull-Rom curve through the points as cubic Béziers — it passes through
/// every chapter's value, so a peak on the curve is a chapter.
Path wavePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = i > 0 ? points[i - 1] : points[i];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = i + 2 < points.length ? points[i + 2] : p2;
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6,
      p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6,
      p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx,
      p2.dy,
    );
  }
  return path;
}

/// The same curve closed down to `baseline`, for the filled wave.
Path waveArea(List<Offset> points, double baseline) {
  if (points.length < 2) return Path();
  return wavePath(points)
    ..lineTo(points.last.dx, baseline)
    ..lineTo(points.first.dx, baseline)
    ..close();
}
