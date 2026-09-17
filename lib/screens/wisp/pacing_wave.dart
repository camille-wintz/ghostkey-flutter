import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/pacing_wave.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'report_card.dart';

/// The book's pacing as a wave: one point per chapter, high for tension or
/// action, low for a lull. The chapter list under it names each point.
class PacingWave extends StatelessWidget {
  const PacingWave({super.key, required this.beats});
  final List<PacingBeat> beats;

  @override
  Widget build(BuildContext context) => ReportCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Peak', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                Text('${beats.length} chapters', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
              ],
            ),
            const SizedBox(height: 4),
            Semantics(
              label: 'Pacing wave, one point per chapter',
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WavePainter(
                    values: [for (final b in beats) b.intensity],
                    line: Ds.accent,
                    base: Ds.edgeHi,
                    mid: Ds.edge,
                    label: Ds.low,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Lull at the baseline', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ),
          ],
        ),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.values, required this.line, required this.base, required this.mid, required this.label});
  final List<double> values;
  final Color line;
  final Color base;
  final Color mid;
  final Color label;

  static const double _labels = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Size(size.width, size.height - _labels);
    const pad = 10.0;
    final points = wavePoints(values, box, pad: pad);
    final baseline = box.height - pad;

    canvas.drawLine(Offset(pad, baseline), Offset(box.width - pad, baseline), Paint()..color = base);
    final dash = Paint()..color = mid;
    for (var x = pad; x < box.width - pad; x += 8) {
      canvas.drawLine(Offset(x, box.height / 2), Offset((x + 3).clamp(0, box.width - pad), box.height / 2), dash);
    }

    canvas.drawPath(waveArea(points, baseline), Paint()..color = line.withValues(alpha: 0.14));
    canvas.drawPath(
      wavePath(points),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = line;
    // Numbers under the axis thin out on a long book, so they stay legible.
    final every = (values.length / 12).ceil().clamp(1, 1 << 20);
    for (final (i, p) in points.indexed) {
      canvas.drawCircle(p, values.length > 30 ? 2.2 : 3, dot);
      if (i % every != 0) continue;
      final text = TextPainter(
        text: TextSpan(text: '${i + 1}', style: DsStyle.ui(const DsStep(10, 12), color: label)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(p.dx - text.width / 2, size.height - text.height));
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => !listEquals(old.values, values) || old.line != line;
}
