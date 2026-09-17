import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../backdrop/ambient_motion.dart';
import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../veil/nightscape.dart';

/// The framed picture on the empty world bible, and its plate. Decorative —
/// excluded from semantics, since "a land drawn from seed 41022" is not
/// information a reader of the page is missing. Still when the phone asks
/// for less movement: a still horizon, not a missing one.
class VeilNightscape extends StatefulWidget {
  const VeilNightscape({super.key});

  @override
  State<VeilNightscape> createState() => _VeilNightscapeState();
}

class _VeilNightscapeState extends State<VeilNightscape> with SingleTickerProviderStateMixin {
  int _seed = math.Random().nextInt(65536);
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);
  NightscapeScene? _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving = ambientMotion(context);
    if (moving && !_ticker.isActive) _ticker.start();
    if (!moving && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  NightscapeScene _sceneFor(Size size) {
    final scene = _scene;
    if (scene != null && scene.width == size.width && scene.height == size.height) return scene;
    return _scene = NightscapeScene.build(_seed, size.width, size.height);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Container(
              height: 248,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Ds.void_, borderRadius: BorderRadius.circular(DsGeom.radius)),
              // In front, or the nearest ridge paints over the frame's bottom edge.
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: Ds.edge),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: LayoutBuilder(
                builder: (context, box) => CustomPaint(
                  size: box.biggest,
                  painter: _NightscapePainter(_sceneFor(box.biggest), _time),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('UNNAMED LAND', style: DsStyle.eyebrow()),
              const SizedBox(width: 12),
              Text(nightscapeLabel(_seed), style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
              const Spacer(),
              Press(
                onPressed: () => setState(() {
                  _seed = math.Random().nextInt(65536);
                  _scene = null;
                }),
                semanticLabel: 'Draw another',
                builder: (context, pressed) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Draw another',
                    style: DsStyle.ui(DsText.ui, color: pressed ? Ds.accent300 : Ds.accent),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}

class _NightscapePainter extends CustomPainter {
  _NightscapePainter(this.scene, this.time) : super(repaint: time);

  final NightscapeScene scene;
  final ValueListenable<double> time;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final w = scene.width;
    final h = scene.height;
    final void_ = Ds.void_;
    final accent = Ds.accent;
    final hi = Ds.hi;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mix(void_, accent, 0.16), _mix(void_, accent, 0.05), _mix(void_, accent, 0.02)],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    final starInk = _mix(accent, hi, 0.7);
    for (final star in scene.stars) {
      final alpha = 0.18 + 0.3 * (0.5 + 0.5 * math.sin(t * 0.7 + star.phase));
      canvas.drawCircle(Offset(star.x * w, star.y * h), star.r, Paint()..color = starInk.withValues(alpha: alpha));
    }

    final moon = scene.moon;
    final centre = Offset(moon.x * w, moon.y * h);
    // A 7.5s breath, slow enough to be felt rather than watched.
    final reach = moon.r * 4 * (1 + 0.06 * math.sin((t / 7.5) * math.pi * 2));
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [_mix(accent, hi, 0.55), accent.withValues(alpha: 0.32), accent.withValues(alpha: 0)],
          stops: const [0, 0.12, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: reach)),
    );

    for (final ridge in scene.ridges) {
      final offset = (t * ridge.speed) / ridge.period;
      final path = Path()..moveTo(0, h);
      // Every 2px: a curve this soft is indistinguishable from per-pixel, at
      // half the path.
      for (var x = 0.0; x <= w; x += 2) {
        path.lineTo(x, ridge.base - ridge.at(x / ridge.period + offset) * ridge.amp);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = _mix(void_, accent, ridge.tint * 0.42));
    }
  }

  @override
  bool shouldRepaint(_NightscapePainter old) => old.scene != scene;
}
