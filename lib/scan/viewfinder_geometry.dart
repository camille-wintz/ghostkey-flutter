import 'dart:ui';

// Where the camera preview lands inside the viewfinder box, and how a tap on
// the box maps back onto it.
//
// The preview is drawn `BoxFit.cover`: scaled to fill the box and cropped at
// the edges. A tap-to-focus point is sent to the camera as a fraction of the
// PREVIEW (0..1 on each axis, display-oriented), so a tap on the box has to
// be mapped through that crop — a tap in the box's top-left corner is not
// the preview's top-left corner when the preview is wider than the box.

/// The rectangle `content` occupies inside `box` under `BoxFit.cover`.
Rect coverRect(Size box, Size content) {
  if (content.width <= 0 || content.height <= 0 || box.isEmpty) return Offset.zero & box;
  final scale = _max(box.width / content.width, box.height / content.height);
  final size = Size(content.width * scale, content.height * scale);
  final origin = Offset((box.width - size.width) / 2, (box.height - size.height) / 2);
  return origin & size;
}

/// `local` (a point in the box) as a fraction of `rect`, or null when it falls
/// outside the drawn preview.
Offset? normalizeIn(Rect rect, Offset local) {
  if (rect.width <= 0 || rect.height <= 0) return null;
  final x = (local.dx - rect.left) / rect.width;
  final y = (local.dy - rect.top) / rect.height;
  if (x < 0 || x > 1 || y < 0 || y > 1) return null;
  return Offset(x, y);
}

double _max(double a, double b) => a > b ? a : b;
