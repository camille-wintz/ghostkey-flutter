import 'package:flutter/widgets.dart';

/// A soft circular bloom — the system's `radial-gradient(circle, …)` recipe:
/// the colour at the centre, faded to nothing by `falloff` of the radius.
///
/// [mid] is the third stop the big lights carry. Without it a bloom falls off
/// linearly, which is what made the phone's moon read as one solid disc where
/// the desktop's is a bright core in a wide faint halo: the system's moon is
/// already down to 9% alpha by 44% of its radius, and the linear two-stop
/// version is still at 66% there.
class Glow extends StatelessWidget {
  const Glow({
    super.key,
    required this.size,
    required this.color,
    required this.opacity,
    this.falloff = 0.65,
    this.mid,
  });

  final double size;
  final Color color;
  final double opacity;
  final double falloff;

  /// `(colour, alpha, position)` — the stop between the centre and nothing.
  final (Color, double, double)? mid;

  @override
  Widget build(BuildContext context) {
    final mid = this.mid;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              if (mid != null) mid.$1.withValues(alpha: mid.$2),
              color.withValues(alpha: 0),
            ],
            stops: [0, if (mid != null) mid.$3, falloff],
          ),
        ),
      ),
    );
  }
}
