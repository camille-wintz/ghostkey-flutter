import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';

/// What a reader felt at a moment of the book. Losing the thread takes the
/// warm hue — worth a look, never a fault.
class ReactionChip extends StatelessWidget {
  const ReactionChip({super.key, required this.reaction});
  final BetaReaction reaction;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (reaction) {
      BetaReaction.hooked => ('Hooked', Ds.accent),
      BetaReaction.delighted => ('Delighted', Ds.accent),
      BetaReaction.moved => ('Moved', Ds.accent),
      BetaReaction.laughed => ('Laughed', Ds.accent),
      BetaReaction.surprised => ('Surprised', Ds.done),
      BetaReaction.guessed => ('Guessed it', Ds.done),
      BetaReaction.confused => ('Lost the thread', Ds.attention),
      BetaReaction.drifted => ('Drifted', Ds.attention),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Text(label, style: DsStyle.ui(DsText.eyebrow, color: color)),
    );
  }
}
