import 'package:flutter/material.dart';

import '../../backdrop/ambient_motion.dart';
import '../../backdrop/glow.dart';
import '../../backdrop/motes.dart';
import '../../ds/tokens.dart';

/// The launcher stage, lit by the book that is open on it: the cover blown
/// up and blurred past recognition, the wash that turns it back into a night,
/// a moon bleeding in off one edge, and the drifting dust. A project with no
/// cover yet gets the system's fallback bloom, so the screen still opens on
/// a sky.
class ProjectBackdrop extends StatelessWidget {
  const ProjectBackdrop({super.key, required this.backdropUrl});

  /// The server's pre-blurred cover — a couple of kilobytes with the blur
  /// already in it. This used to be the full-size cover, blurred here: a
  /// megabyte or two over a phone connection, then a decode, then a
  /// sigma-40 pass, and the stage stayed black through all three.
  final String? backdropUrl;

  @override
  Widget build(BuildContext context) {
    final moving = ambientMotion(context);
    final width = MediaQuery.sizeOf(context).width;
    // The desktop moon is an 820px disc — 64% of its 1280px window — parked
    // 192px (15% of the window) left of centre. Both are read as fractions of
    // the width so the phone gets the same composition rather than the same
    // pixels: scaling the disc to the screen, as this did, made it 160% of the
    // width, and a bloom that size stops being a moon and becomes the weather.
    final moon = (width * 0.64).roundToDouble();

    return IgnorePointer(
      child: RepaintBoundary(
        child: ColoredBox(
          color: Ds.void_,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const _FallbackBloom(),
              if (backdropUrl != null)
                Positioned.fill(
                  left: -width * 0.14,
                  right: -width * 0.14,
                  top: -60,
                  bottom: -60,
                  child: Image.network(
                    backdropUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.44),
                    // Already blurred and painted three times its own size, so
                    // there is nothing for a better sampler to recover.
                    filterQuality: FilterQuality.low,
                    // A cover that will not load leaves the fallback sky under
                    // it rather than a hole.
                    errorBuilder: (context, _, _) => const SizedBox.shrink(),
                    // No fade: the picture IS the loading state of the screen
                    // behind it, and a cross-fade on top of the room's own
                    // entry animation reads as a stutter.
                  ),
                ),
              // `brightness(.42)` has no widget equivalent; a scrim of the
              // window's own near-black takes the cover back to a night sky.
              if (backdropUrl != null) const ColoredBox(color: Color(0x6B0A0914)),
              const _Wash(),
              Positioned(
                left: width * 0.35 - moon / 2,
                top: MediaQuery.sizeOf(context).height / 2 - moon / 2,
                child: Glow(
                  size: moon,
                  color: const Color(0xFFCAD2F0),
                  opacity: 0.32,
                  mid: (const Color(0xFF7E98DE), 0.09, 0.44),
                  falloff: 0.66,
                ),
              ),
              // The motes animate; on their own boundary the still layers
              // under them are not repainted for every speck that rises.
              Motes(moving: moving),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sky a coverless project opens on — and the ground under every other
/// one, so a backdrop that has not arrived yet shows a night rather than a
/// black rectangle.
class _FallbackBloom extends StatelessWidget {
  const _FallbackBloom();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF151A30), Color(0xFF08070F), Color(0xFF08070F)],
            stops: [0, 0.7, 1],
          ),
        ),
      );
}

/// The two ellipses that make a blurred paperback read as weather: a cool
/// light from the upper left, and a deep corner bottom right that the room
/// list sits against.
class _Wash extends StatelessWidget {
  const _Wash();

  @override
  Widget build(BuildContext context) => const Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.64, 0.84),
                radius: 1.2,
                colors: [Color(0x8C0D1026), Color(0xF006050E), Color(0xF006050E)],
                stops: [0, 0.76, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.48, -0.52),
                radius: 1.15,
                colors: [Color(0x4D607ED6), Color(0x00607ED6)],
                stops: [0, 0.58],
              ),
            ),
          ),
        ],
      );
}
