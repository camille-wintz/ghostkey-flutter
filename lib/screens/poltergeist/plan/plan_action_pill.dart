import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/plan_markers.dart';
import '../../../ds/tokens.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/press.dart';

/// The action pill: what this chapter still needs done. Past the last action
/// the row reads DONE in the settled hue; a row that is merely clean (moved,
/// say, but never line edited) shows its last completed action with a quiet
/// check. Pressing it opens the menu; a row with no live chapter has nothing
/// to act on.
class PlanActionPill extends StatelessWidget {
  const PlanActionPill({super.key, required this.chapter, required this.onPressed, this.disabled = false});
  final PlanChapter chapter;
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final action = chapter.pending;
    final lastDone = chapter.history.isNotEmpty ? chapter.history.last : null;
    final done = action == null && chapter.done;
    final inert = disabled || chapter.documentId == null;

    final Color ink;
    final Color border;
    Color? fill;
    if (action != null) {
      final hue = planColor(action.kind);
      ink = hue;
      border = hue.withValues(alpha: action.kind == PlanActionKind.move ? 0.6 : 0.45);
      if (action.kind == PlanActionKind.delete) fill = hue.withValues(alpha: 0.1);
    } else if (done) {
      ink = Ds.done;
      border = Ds.done.withValues(alpha: 0.35);
    } else {
      ink = Ds.low;
      border = const Color(0x00000000);
    }
    final label = action != null
        ? action.kind.label
        : done
            ? 'Done'
            : lastDone?.kind.doneLabel ?? '—';

    return Press(
      onPressed: onPressed,
      enabled: !inert,
      semanticLabel: action != null || done ? label : 'Assign an action',
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : fill,
          border: Border.all(color: pressed && action == null && !done ? Ds.edgeHi : border),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (action != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: ink, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ] else if (done || lastDone != null) ...[
              Icon(LucideIcons.check, size: 10, color: done ? Ds.done : Ds.done.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: DsStyle.ui(DsText.eyebrow, color: ink, weight: FontWeight.w600, tracking: DsTracking.pill),
            ),
          ],
        ),
      ),
    );
  }
}
