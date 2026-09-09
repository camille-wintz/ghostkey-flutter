import 'package:flutter/widgets.dart';

import 'glow.dart';

/// The design's own twenty, from its own deterministic formula, so the dust
/// reads the same here as on the desk: left%, size, seconds, delay, sideways
/// drift.
///
/// The first port of this took the desktop's `--mote-o` for the speck's
/// opacity. That variable only tints the DAY launcher; at night every mote
/// crests at 0.85, and the port's 0.3–0.69 made a field of dust that was
/// technically there and visually wasn't. It also seated each mote at a fixed
/// height and let it rise 134px, where the original crosses the whole screen —
/// so what should read as motes drifting through a room read as a dozen
/// specks twitching in place, and the big glow behind them was the only thing
/// on the screen that looked like light.
final List<_Spec> _motes = List.generate(20, (i) {
  return _Spec(
    left: ((i * 8.7 + (i % 4) * 5) % 97) + 1.5,
    size: 2.5 + (i % 4) * 2.2,
    duration: Duration(milliseconds: ((12 + (i % 6) * 3.5) * 1000).round()),
    // Negative delays on the web start the animation part-way through, so the
    // field is already populated on the first frame rather than filling up
    // over the first half-minute. A ticker cannot start in the past, so the
    // offset is carried as a phase instead.
    phase: ((i * 2.3) % 20) / (12 + (i % 6) * 3.5),
    drift: (i.isOdd ? 1 : -1) * (16 + (i % 4) * 16),
  );
});

class _Spec {
  const _Spec({
    required this.left,
    required this.size,
    required this.duration,
    required this.phase,
    required this.drift,
  });
  final double left;
  final double size;
  final Duration duration;
  final double phase;
  final double drift;
}

const Color _moteColor = Color(0xFFE4ECFF);

/// Every speck crests at the same brightness — depth is read from size and
/// speed, not from a dimmer.
const double _peak = 0.85;

/// The launcher's drifting dust, filling whatever it is laid over. Nothing is
/// drawn at all when `moving` is false — a parked mote is a speck of grit on
/// the glass, which is worse than none.
class Motes extends StatelessWidget {
  const Motes({super.key, required this.moving});
  final bool moving;

  @override
  Widget build(BuildContext context) {
    if (!moving) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              for (final spec in _motes)
                _Mote(spec: spec, width: constraints.maxWidth, height: constraints.maxHeight),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rising speck: from just below the bottom edge to just above the top,
/// drifting sideways as it goes, fading in over the first eighth of the climb
/// and thinning out across the rest.
class _Mote extends StatefulWidget {
  const _Mote({required this.spec, required this.width, required this.height});
  final _Spec spec;
  final double width;
  final double height;

  @override
  State<_Mote> createState() => _MoteState();
}

class _MoteState extends State<_Mote> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: widget.spec.duration)
    ..value = widget.spec.phase % 1
    ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// The web keyframe: 0 → .85 by 12%, down to .40 by 88%, out by the end.
  double _opacity(double p) {
    if (p < 0.12) return _peak * p / 0.12;
    if (p < 0.88) return _peak * (1 - 0.53 * (p - 0.12) / 0.76);
    return _peak * 0.47 * (1 - (p - 0.88) / 0.12);
  }

  @override
  Widget build(BuildContext context) {
    // The climb: seated 30px below the bottom edge, gone 40px above the top.
    final travel = widget.height + 70;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final p = _t.value;
        return Positioned(
          left: widget.width * widget.spec.left / 100 + widget.spec.drift * p,
          top: widget.height + 30 - p * travel,
          child: Opacity(opacity: _opacity(p).clamp(0, 1), child: child),
        );
      },
      child: Glow(size: widget.spec.size, color: _moteColor, opacity: 0.95, falloff: 0.7),
    );
  }
}
