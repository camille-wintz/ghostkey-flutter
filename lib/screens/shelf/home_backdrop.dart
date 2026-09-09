import 'package:flutter/material.dart';

import '../../backdrop/ambient_motion.dart';
import '../../backdrop/glow.dart';
import '../../backdrop/motes.dart';
import '../../ds/tokens.dart';

/// Home's sky: a long cool gradient, two cornflower glows bleeding in off the
/// edges, and a slow drift of motes. Purely decorative and entirely behind
/// the content. Home has no book to be lit by, which is what separates it
/// from the project backdrop: the light comes from the palette.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key});

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3750),
  );

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = ambientMotion(context);
    if (moving && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!moving && _breath.isAnimating) {
      _breath.stop();
    }

    final width = MediaQuery.sizeOf(context).width;
    // Both lights are read as fractions of the width, on the desktop moon's
    // own proportions (64% of the window). Typed as 460 and 380 they were
    // 118% and 97% of a phone — two blooms wider than the screen, which is a
    // wash, not a light, and left nothing else on the screen to look at.
    final near = (width * 0.64).roundToDouble();
    final far = (width * 0.52).roundToDouble();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              // The CSS `linear-gradient(168deg, …)`: mostly down, leaning right.
              gradient: LinearGradient(
                begin: const Alignment(-0.21, -0.98),
                end: const Alignment(0.21, 0.98),
                colors: [const Color(0xFF141A33), const Color(0xFF0D1020), Ds.void_],
                stops: const [0, 0.46, 1],
              ),
            ),
          ),
          Positioned(
            left: -near * 0.42,
            top: 40,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_breath.value);
                return Opacity(
                  opacity: 0.5 + t * 0.3,
                  child: Transform.scale(scale: 1 + t * 0.05, child: child),
                );
              },
              // The moon's own three-stop fall: a bright core in a wide faint
              // halo, rather than a solid disc fading linearly to its edge.
              child: Glow(
                size: near,
                color: Ds.accent,
                opacity: 0.22,
                mid: (Ds.accent, 0.06, 0.44),
                falloff: 0.66,
              ),
            ),
          ),
          Positioned(
            right: -far * 0.42,
            top: 420,
            child: Glow(
              size: far,
              color: Ds.accent,
              opacity: 0.12,
              mid: (Ds.accent, 0.03, 0.44),
              falloff: 0.66,
            ),
          ),
          Motes(moving: moving),
        ],
      ),
    );
  }
}
