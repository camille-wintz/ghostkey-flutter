import 'package:flutter/widgets.dart';

import '../ds/tokens.dart';

/// The ring a tap-to-focus leaves behind: settles from slightly large to its
/// size in the house's one duration, centred on the tap.
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.at});
  final Offset at;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: at.dx - _size / 2,
      top: at.dy - _size / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(at),
          tween: Tween(begin: 1.3, end: 1),
          duration: DsMotion.duration,
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Ds.accent, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
