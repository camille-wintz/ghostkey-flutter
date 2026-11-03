import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../ds/tokens.dart';

/// One piece of the work, as a bead around the moon.
enum MoonBead { lit, working, waiting, quiet, failed }

/// How far a piece of work has got, as a moon: it waxes as the beads around it
/// finish. The desk's is `src/shared/components/ProgressMoon.tsx`.
class ProgressMoon extends StatefulWidget {
  const ProgressMoon({super.key, required this.beads, required this.label, this.size = 240});

  /// One per piece of the work, in order, clockwise from the top.
  final List<MoonBead> beads;
  final String label;
  final double size;

  @override
  State<ProgressMoon> createState() => _ProgressMoonState();
}

class _ProgressMoonState extends State<ProgressMoon> with SingleTickerProviderStateMixin {
  /// A sliver from the first moment anything is working, so a run at nought is not a dark disc.
  static const _firstSliver = 0.07;

  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3750));

  double get _fraction {
    final beads = widget.beads;
    if (beads.isEmpty) return 0;
    final finished = beads.where((b) => b == MoonBead.lit || b == MoonBead.quiet || b == MoonBead.failed).length;
    final fraction = finished / beads.length;
    return beads.contains(MoonBead.working) ? math.max(_firstSliver, fraction) : fraction;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _fraction),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (_, fraction, _) => CustomPaint(
            painter: _MoonPainter(beads: widget.beads, fraction: fraction, breath: _breath),
          ),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.beads, required this.fraction, required this.breath}) : super(repaint: breath);

  final List<MoonBead> beads;
  final double fraction;
  final Animation<double> breath;

  static const _box = 320.0;
  static const _moonRadius = 92.0;
  static const _ringRadius = 136.0;

  Color _fill(MoonBead bead) => switch (bead) {
        MoonBead.lit || MoonBead.working => Ds.attention400,
        MoonBead.waiting => Ds.edgeHi,
        MoonBead.quiet => Ds.low,
        MoonBead.failed => Ds.destructive,
      };

  double get _beadRadius => switch (beads.length) {
        <= 12 => 5,
        <= 30 => 4,
        <= 60 => 3,
        _ => 2,
      };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box);
    const centre = Offset(_box / 2, _box / 2);

    canvas.drawCircle(
      centre,
      _moonRadius * (1 + 0.06 * breath.value),
      Paint()
        ..color = Ds.accent.withValues(alpha: 0.24 + 0.14 * breath.value)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawCircle(centre, _moonRadius, Paint()..color = Ds.surf);
    if (fraction > 0) canvas.drawPath(_litPart(centre), Paint()..color = Ds.hi);

    for (final (i, bead) in beads.indexed) {
      final angle = -math.pi / 2 + (i / beads.length) * math.pi * 2;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * _ringRadius;
      final alpha = bead == MoonBead.working ? 0.45 + 0.55 * breath.value : 1.0;
      final colour = _fill(bead).withValues(alpha: alpha);
      if (bead != MoonBead.waiting && bead != MoonBead.quiet) {
        canvas.drawCircle(
          at,
          _beadRadius + 1,
          Paint()
            ..color = colour.withValues(alpha: 0.42 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(at, _beadRadius, Paint()..color = colour);
    }
  }

  /// The right limb, back along the terminator.
  Path _litPart(Offset centre) {
    final terminator = math.max(0.01, _moonRadius * (1 - 2 * fraction).abs());
    return Path()
      ..moveTo(centre.dx, centre.dy - _moonRadius)
      ..arcToPoint(Offset(centre.dx, centre.dy + _moonRadius), radius: const Radius.circular(_moonRadius))
      ..arcToPoint(
        Offset(centre.dx, centre.dy - _moonRadius),
        radius: Radius.elliptical(terminator, _moonRadius),
        clockwise: fraction >= 0.5,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.fraction != fraction || old.beads != beads;
}
