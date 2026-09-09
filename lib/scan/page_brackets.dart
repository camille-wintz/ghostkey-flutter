import 'package:flutter/widgets.dart';

import '../ds/tokens.dart';

/// The page-detection frame over the preview: four accent corners inset from
/// the viewfinder (14% each side, 20% at the foot, as the RN overlay drew
/// them) and a hint beneath. Lets every touch through to the preview.
class PageBrackets extends StatelessWidget {
  const PageBrackets({super.key, required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BracketsPainter(color: Ds.accent)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.ui, color: Ds.mid),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketsPainter extends CustomPainter {
  const _BracketsPainter({required this.color});
  final Color color;

  static const double _arm = 26;
  static const double _stroke = 3;
  static const double _round = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTRB(
      size.width * 0.14,
      size.height * 0.14,
      size.width * 0.86,
      size.height * 0.80,
    ).inflate(2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;

    // Each corner: an L whose joint is rounded, drawn as two arms meeting on
    // a small arc. `sx`/`sy` flip the L into the other three corners.
    void corner(Offset apex, double sx, double sy) {
      final path = Path()
        ..moveTo(apex.dx, apex.dy + sy * _arm)
        ..lineTo(apex.dx, apex.dy + sy * _round)
        ..quadraticBezierTo(apex.dx, apex.dy, apex.dx + sx * _round, apex.dy)
        ..lineTo(apex.dx + sx * _arm, apex.dy);
      canvas.drawPath(path, paint);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_BracketsPainter oldDelegate) => oldDelegate.color != color;
}
