import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// The interview's sitting so far, as a row of dots: gold for an answer (the
/// colour of words that counted), dim for a skip, and the accent, lit, for
/// the question being asked. Only the newest fit, as on the desk.
class InterviewDots extends StatelessWidget {
  const InterviewDots({super.key, required this.trail});
  final List<bool> trail;

  static const _shown = 11;

  @override
  Widget build(BuildContext context) {
    final recent = trail.length > _shown ? trail.sublist(trail.length - _shown) : trail;
    return ExcludeSemantics(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final answered in recent) _Dot(answered ? Ds.attention : Ds.faint, glow: answered),
          _Dot(Ds.accent, glow: true, size: 10),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {required this.glow, this.size = 8});
  final Color color;
  final bool glow;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)] : null,
        ),
      );
}
