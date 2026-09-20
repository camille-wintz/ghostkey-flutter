import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import '../rooms/icons.dart';
import '../rooms/room_tile.dart';
import '../rooms/rooms.dart';
import 'cat_picture.dart';
import 'strike.dart';

// A milestone struck like a coin at the foot of the page: the card lands, the
// mark strikes, the ring closes, the words rise, a sheen crosses and six
// motes drift up off its foot. It holds a few seconds and goes on a short
// fade. From the "Writing streak reward" canvas; the desktop's
// `RewardStrike.tsx` is the same card in CSS.

/// The design's ease for everything that arrives: a long ease-out tail.
const Cubic _arrive = Cubic(0.16, 1, 0.3, 1);

/// One playthrough of the entrance, long enough for the last mote to fade.
const Duration _entrance = Duration(milliseconds: 4300);
const Duration _exit = Duration(milliseconds: 260);

/// The headline's step, from the canvas: between title and display.
const DsStep _headline = DsStep(32, 34);

/// Where the motes rise from and when — six, spread along the foot of the
/// card so no stretch goes bare. `left` is a fraction of the width.
class _Mote {
  const _Mote(this.left, this.bottom, this.size, this.delay, this.duration, this.tint);
  final double left;
  final double bottom;
  final double size;
  final int delay;
  final int duration;
  final int tint;
}

const List<_Mote> _motes = [
  _Mote(0.14, 8, 3, 120, 2600, 0),
  _Mote(0.28, 2, 2, 420, 3100, 1),
  _Mote(0.41, 12, 3, 260, 2900, 2),
  _Mote(0.57, 0, 2, 700, 3400, 0),
  _Mote(0.70, 10, 3, 540, 2700, 1),
  _Mote(0.86, 4, 2, 900, 3200, 2),
];

class RewardStrikeCard extends StatefulWidget {
  const RewardStrikeCard({
    super.key,
    required this.strike,
    required this.leaving,
    required this.onDismiss,
    required this.onGone,
  });

  final Strike strike;

  /// Playing its way out; [onGone] follows.
  final bool leaving;
  final VoidCallback onDismiss;

  /// The exit has finished playing.
  final VoidCallback onGone;

  @override
  State<RewardStrikeCard> createState() => _RewardStrikeCardState();
}

class _RewardStrikeCardState extends State<RewardStrikeCard> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: _entrance);
  late final AnimationController _out = AnimationController(vsync: this, duration: _exit);

  @override
  void initState() {
    super.initState();
    _out.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onGone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the card is simply there, and simply gone.
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      _out.duration = const Duration(milliseconds: 1);
    } else if (!_in.isAnimating && _in.value == 0) {
      _in.forward();
    }
    if (widget.leaving && !_out.isAnimating && _out.value == 0) _out.forward();
  }

  @override
  void didUpdateWidget(RewardStrikeCard old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _out.forward();
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  /// Where one piece of the entrance stands, 0–1, given when it starts and
  /// how long it runs — the CSS `animation-delay` and `animation-duration`.
  double _seg(int startMs, int durationMs) {
    final ms = _in.value * _entrance.inMilliseconds;
    return ((ms - startMs) / durationMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final strike = widget.strike;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, _) {
        final out = Curves.easeIn.transform(_out.value);
        return Opacity(
          opacity: 1 - out,
          child: Transform.translate(
            offset: Offset(0, 8 * out),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: -34, right: -34, top: -30, bottom: -30, child: _bloom()),
                _card(context, strike),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The accent pooled behind the card, blurred wide, that flares as the
  /// card lands and settles to a glow.
  Widget _bloom() {
    final t = _arrive.transform(_seg(0, 900));
    final double opacity;
    final double scale;
    if (t < 0.3) {
      final k = t / 0.3;
      opacity = 0.9 * k;
      scale = 0.45 + (1.06 - 0.45) * k;
    } else {
      final k = (t - 0.3) / 0.7;
      opacity = 0.9 + (0.42 - 0.9) * k;
      scale = 1.06 + (1 - 1.06) * k;
    }
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DsGeom.radiusRound),
                gradient: RadialGradient(
                  colors: [Ds.accentMix(34), Ds.accentMix(0)],
                  stops: const [0, 0.78],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Strike strike) {
    final t = _arrive.transform(_seg(0, 420));
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - t)),
        child: Transform.scale(
          scale: 0.965 + 0.035 * t,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Semantics(
              liveRegion: true,
              label: '${strike.eyebrow}. ${strike.headline}. ${strike.sub}',
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Ds.surf,
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                  border: Border.all(color: Ds.edgeHi),
                  // The one shadow the design asks for: the card sits ON the
                  // page for a moment.
                  boxShadow: const [
                    BoxShadow(color: Color(0xCC000000), blurRadius: 48, spreadRadius: -18, offset: Offset(0, 18)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.64, -1),
                              radius: 1.1,
                              colors: [Ds.accentMix(14), Ds.accentMix(0)],
                              stops: const [0, 0.62],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(child: IgnorePointer(child: _sheen())),
                    Positioned.fill(child: IgnorePointer(child: _moteField())),
                    _body(strike),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A pale band that crosses the card once, left to right, slanted.
  Widget _sheen() {
    final t = Curves.easeOut.transform(_seg(240, 1700));
    // Still for the first 14%, across by 52%, then gone off the right.
    final k = ((t - 0.14) / (0.52 - 0.14)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        const width = 64.0;
        final dx = -1.6 * width + k * (box.maxWidth + 1.6 * width + 3.2 * width);
        return Stack(
          children: [
            Positioned(
              left: dx,
              top: 0,
              bottom: 0,
              width: width,
              child: Transform(
                transform: Matrix4.skewX(-16 * math.pi / 180),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00E2ECFF), Color(0x1AE2ECFF), Color(0x00E2ECFF)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _moteField() {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    final tints = [Ds.accent200, Ds.accent300, Ds.attention300];
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final m in _motes)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final t = Curves.easeOut.transform(_seg(m.delay, m.duration));
                final opacity = t < 0.22 ? 0.9 * (t / 0.22) : 0.9 * (1 - (t - 0.22) / 0.78);
                return Align(
                  alignment: Alignment(m.left * 2 - 1, 1),
                  child: Transform.translate(
                    offset: Offset(0, -m.bottom + 10 - 130 * t),
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * t,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: m.size,
                          height: m.size,
                          decoration: BoxDecoration(color: tints[m.tint], shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _body(Strike strike) {
    final ticked = strike.ticked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _medallion(strike),
              const SizedBox(width: 16),
              Expanded(
                child: _rise(
                  start: 180,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strike.eyebrow.toUpperCase(), style: DsStyle.eyebrow(color: Ds.accent300)),
                        const SizedBox(height: 5),
                        Text(strike.headline, style: DsStyle.prose(_headline, color: Ds.hi), maxLines: 2),
                        const SizedBox(height: 5),
                        Text(strike.sub, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _rise(
            start: 320,
            child: Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
              child: Row(
                children: [
                  if (ticked != null)
                    Semantics(
                      label: '$ticked of $chainDays days this week',
                      child: Row(
                        children: [
                          for (var i = 0; i < chainDays; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _dot(on: i < ticked),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Right-aligned and clipped rather than wrapped: on a narrow
                  // phone the chain keeps its dots and the note gives way.
                  Expanded(
                    child: Text(
                      strike.footnote.toUpperCase(),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: DsText.eyebrow.size * 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot({required bool on}) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? Ds.accent : null,
          border: on ? null : Border.all(color: Ds.edgeHi),
        ),
      );

  /// A block that fades up into place — the words, then the chain.
  Widget _rise({required int start, required Widget child}) {
    final t = _arrive.transform(_seg(start, 460));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    );
  }

  /// The ring closing round the mark, and the mark striking inside it.
  Widget _medallion(Strike strike) {
    final ring = strike.ring * _arrive.transform(_seg(160, 1100));
    final s = _arrive.transform(_seg(80, 620));
    final double scale;
    final double angle;
    final double opacity;
    if (s < 0.58) {
      final k = s / 0.58;
      opacity = k;
      scale = 0.5 + (1.09 - 0.5) * k;
      angle = -10 + 12 * k;
    } else {
      final k = (s - 0.58) / 0.42;
      opacity = 1;
      scale = 1.09 - 0.09 * k;
      angle = 2 - 2 * k;
    }
    final cat = strike.cat;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _RingPainter(progress: ring, track: Ds.edgeHi, ink: Ds.accent))),
          Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: angle * math.pi / 180,
              child: Transform.scale(
                scale: scale,
                child: cat != null
                    ? Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Ds.veil,
                          border: Border.all(color: Ds.edgeHi),
                        ),
                        child: ClipOval(child: CatPicture(cat)),
                      )
                    : RoomTile(
                        tile: rooms.firstWhere((r) => r.key == RoomKey.poltergeist).tile,
                        mark: RoomMark.poltergeist,
                        size: 52,
                        iconSize: 25,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 2px track and the accent arc that closes over it, from twelve o'clock.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.track, required this.ink});
  final double progress;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    const r = 32.0;
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.ink != ink;
}
