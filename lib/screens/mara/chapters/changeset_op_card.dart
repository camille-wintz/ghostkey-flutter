import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/press.dart';
import '../../../ui/text.dart';
import 'changeset_badges.dart';

/// One proposed change as a card: why, which chapters it names, and the
/// author's answer — skipped, a skipped op simply is not applied and the
/// chapters it names stay as they are.
class ChangesetOpCard extends StatelessWidget {
  const ChangesetOpCard({
    super.key,
    required this.op,
    required this.skipped,
    required this.onToggle,
    this.orphan = false,
    this.onOpen,
  });
  final ChangesetOp op;
  final bool skipped;
  final VoidCallback onToggle;

  /// It names no chapter this draft has.
  final bool orphan;

  /// Open the chapters it writes, when it writes any.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final badge = opBadge(op);
    final named = switch (op) {
      ChangesetRemove(:final chapters) || ChangesetRewrite(:final chapters) => chapters.map((c) => c.filename).toList(),
      ChangesetAdd(:final written) => written.map((c) => c.title).toList(),
    };
    return Press(
      onPressed: onOpen,
      semanticLabel: '${badge.label} change${skipped ? ', skipped' : ''}',
      builder: (context, pressed) => Opacity(
        opacity: skipped ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.fromLTRB(28, 6, 4, 6),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : Ds.panel,
            border: Border.all(color: badge.color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(DsGeom.radius - 6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Eyebrow(badge.label, color: badge.color),
                  const Spacer(),
                  Press(
                    onPressed: onToggle,
                    hitSlop: 6,
                    semanticLabel: skipped ? 'Restore this change' : 'Skip this change',
                    builder: (context, pressed) => Text(
                      skipped ? 'Restore' : 'Skip',
                      style: DsStyle.ui(DsText.ui, color: pressed ? Ds.hi : Ds.soft, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (orphan) ...[
                const SizedBox(height: 4),
                UiText('Names chapters this draft no longer has.', step: DsText.ui, color: Ds.low),
              ],
              if (named.isNotEmpty) ...[
                const SizedBox(height: 6),
                UiText(named.map((n) => n.replaceAll(RegExp(r'\.md$', caseSensitive: false), '')).join(' · '), color: Ds.soft),
              ],
              if (op.reason.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(op.reason, style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(height: 1.45)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
