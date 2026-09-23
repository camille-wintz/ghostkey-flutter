import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The first book on the shelf is the one not written yet (the desk's
/// `NewNovelCard`): an empty cover the same size as the rest, so starting a
/// novel sits where the novels are rather than in a form above them.
class NewNovelCard extends StatelessWidget {
  const NewNovelCard({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: 'New novel',
        builder: (context, pressed) => Column(
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: CustomPaint(
                painter: _DashedFrame(color: pressed ? Ds.accentMix(55) : Ds.edgeHi),
                child: Container(
                  decoration: BoxDecoration(
                    color: Ds.veil,
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(LucideIcons.plus, size: 32, color: pressed ? Ds.accent : Ds.low),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'New novel',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: DsStyle.ui(const DsStep(15, 20), color: Ds.hi, weight: FontWeight.w600),
            ),
          ],
        ),
      );
}

/// The desk's `border-dashed` — Flutter's borders are solid only.
class _DashedFrame extends CustomPainter {
  const _DashedFrame({required this.color});
  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        const Radius.circular(DsGeom.radius),
      ));
    for (final metric in outline.computeMetrics()) {
      for (double d = 0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) => old.color != color;
}
