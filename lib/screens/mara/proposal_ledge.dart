import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// A proposal is pending and lives on the Chapters page — one line over the
/// plan saying so, with the two ways out.
class ProposalLedge extends StatelessWidget {
  const ProposalLedge({
    super.key,
    required this.count,
    required this.changeset,
    required this.onReview,
    required this.onDismiss,
    required this.dismissing,
    this.madeFrom,
    this.consequence,
  });

  /// Chapters in a proposal, or ops in a changeset.
  final int count;
  final bool changeset;

  /// "this board" / "this outline", when the proposal was read from the plan
  /// on screen.
  final String? madeFrom;

  /// What that means for editing the plan, when it was.
  final String? consequence;
  final VoidCallback onReview;
  final VoidCallback onDismiss;
  final bool dismissing;

  @override
  Widget build(BuildContext context) {
    final what = changeset
        ? '$count ${count == 1 ? 'change' : 'changes'} proposed'
        : '$count ${count == 1 ? 'chapter' : 'chapters'} proposed';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Ds.accentMix(8),
        border: Border.all(color: Ds.accentMix(30)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: what, style: DsStyle.ui(DsText.ui, color: Ds.hi, weight: FontWeight.w600)),
                TextSpan(text: madeFrom == null ? '.' : ' from $madeFrom.'),
              ],
            ),
            style: DsStyle.ui(DsText.ui, color: Ds.soft),
          ),
          if (consequence case final consequence?) ...[
            const SizedBox(height: 4),
            Text(consequence, style: DsStyle.ui(DsText.ui, color: Ds.low)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _LedgeLink(label: 'Review', color: Ds.accent, onPressed: onReview),
              const SizedBox(width: 18),
              _LedgeLink(label: dismissing ? 'Dismissing…' : 'Dismiss', color: Ds.low, onPressed: dismissing ? null : onDismiss),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgeLink extends StatelessWidget {
  const _LedgeLink({required this.label, required this.color, required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        hitSlop: 6,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.7 : 1,
          child: Text(label, style: DsStyle.ui(DsText.ui, color: color, weight: FontWeight.w600)),
        ),
      );
}
