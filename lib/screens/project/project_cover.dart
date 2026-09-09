import 'package:flutter/material.dart';

import '../../backdrop/ambient_motion.dart';
import '../../ds/tokens.dart';

const double _width = 198;
const double _height = 297;

/// The hero on the project home: the book itself, held at an angle and lit.
/// A slight turn away from the reader, a long shadow under it, a highlight
/// down the spine edge and a sheen that crosses the face every eight seconds,
/// over a slow float. A project with no cover gets the same frame around a
/// gradient plate carrying its title.
class ProjectCover extends StatefulWidget {
  const ProjectCover({super.key, required this.coverUrl, required this.title});
  final String? coverUrl;
  final String title;

  @override
  State<ProjectCover> createState() => _ProjectCoverState();
}

class _ProjectCoverState extends State<ProjectCover> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3750));
  late final AnimationController _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 8000));

  @override
  void dispose() {
    _float.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _sync(bool moving) {
    if (moving) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
      if (!_sheen.isAnimating) _sheen.repeat();
    } else {
      _float.stop();
      _sheen.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = ambientMotion(context);
    _sync(moving);

    // The three shadows are wide Gaussian blurs. On their own repaint
    // boundary they are rasterised once; the float then moves a layer rather
    // than re-blurring three shadows sixty times a second.
    final shadow = RepaintBoundary(
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          boxShadow: const [
            BoxShadow(color: Color(0xB8000000), blurRadius: 96, offset: Offset(0, 46)),
            BoxShadow(color: Color(0x8C000000), blurRadius: 30, offset: Offset(0, 10)),
            BoxShadow(color: Color(0x426082D7), blurRadius: 78),
          ],
        ),
      ),
    );

    final face = Container(
      width: _width,
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Ds.surf,
        border: Border.all(color: Ds.edgeHi),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.coverUrl != null)
            Image.network(
              widget.coverUrl!,
              fit: BoxFit.cover,
              semanticLabel: 'Cover of ${widget.title}',
              errorBuilder: (context, _, _) => _Plate(title: widget.title),
            )
          else
            _Plate(title: widget.title),
          // The spine edge: the one place the cover catches the room light.
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          if (moving)
            AnimatedBuilder(
              animation: _sheen,
              builder: (context, child) {
                // The web keyframe travels for the first 58% of its 8s and
                // then waits out the rest, so the pass is a glint.
                final raw = _sheen.value / 0.58;
                final p = raw > 1 ? 1.0 : Curves.easeInOut.transform(raw);
                return Positioned(
                  left: _width * (-2.32 + 3.04 * p),
                  top: 0,
                  bottom: 0,
                  width: _width * 2.6,
                  child: child!,
                );
              },
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1, -0.5),
                    end: Alignment(1, 0.5),
                    colors: [
                      Color(0x00E4EAFC),
                      Color(0x00E4EAFC),
                      Color(0x3DE4EAFC),
                      Color(0x0DFFFFFF),
                      Color(0x00E4EAFC),
                      Color(0x00E4EAFC),
                    ],
                    stops: [0, 0.32, 0.47, 0.5, 0.65, 1],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -15 * Curves.easeInOut.transform(_float.value)),
        child: child,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 1 / 1500)
          ..rotateY(-7 * 3.14159 / 180)
          ..rotateX(2 * 3.14159 / 180),
        child: Stack(
          clipBehavior: Clip.none,
          children: [shadow, RepaintBoundary(child: face)],
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment(0.1, 1),
            colors: [Color(0xFF232A44), Color(0xFF141A2C)],
          ),
        ),
        child: Text(
          title,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DsStyle.prose(const DsStep(20, 27), color: Ds.low),
        ),
      );
}
