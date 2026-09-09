import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/plan_markers.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/press.dart';
import '../../../ui/sheet.dart';

/// What the pill menu can answer with.
sealed class PlanSheetChoice {
  const PlanSheetChoice();
}

class AssignChoice extends PlanSheetChoice {
  const AssignChoice(this.kind);
  final PlanActionKind kind;
}

class ClearChoice extends PlanSheetChoice {
  const ClearChoice();
}

class ConfirmChoice extends PlanSheetChoice {
  const ConfirmChoice();
}

class ToggleDoneChoice extends PlanSheetChoice {
  const ToggleDoneChoice();
}

/// The pill's menu, as a sheet: every action (every row is a real chapter, so
/// `write` is on it too), "No action" when one is pending, Confirm when the
/// board thinks it happened, and — below the kinds, because it is the end of
/// the ladder rather than a sixth action — done, or not.
Future<PlanSheetChoice?> showPlanActionSheet(BuildContext context, PlanChapter chapter) {
  final action = chapter.pending;
  final done = action == null && chapter.done;
  final evidence = readyEvidence(chapter);
  return showGkSheet<PlanSheetChoice>(
    context,
    header: SheetHeader(eyebrow: chapter.label, onClose: () => Navigator.of(context).pop()),
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: [
        if (evidence != null)
          _Item(
            icon: Icon(LucideIcons.check, size: 14, color: Ds.accent),
            label: 'Confirm',
            detail: evidence,
            color: Ds.accent,
            onPressed: () => Navigator.of(context).pop(const ConfirmChoice()),
          ),
        for (final kind in planActionKinds)
          _Item(
            icon: Container(width: 6, height: 6, decoration: BoxDecoration(color: planColor(kind), shape: BoxShape.circle)),
            label: kind.label,
            selected: action?.kind == kind,
            onPressed: () => Navigator.of(context).pop(AssignChoice(kind)),
          ),
        if (action != null)
          _Item(
            icon: const SizedBox(width: 6),
            label: 'No action',
            onPressed: () => Navigator.of(context).pop(const ClearChoice()),
          ),
        Divider(height: 9, thickness: 1, color: Ds.edge),
        _Item(
          icon: done ? const SizedBox(width: 12) : Icon(LucideIcons.check, size: 12, color: Ds.done.withValues(alpha: 0.8)),
          label: done ? 'Not done' : 'Mark done',
          onPressed: () => Navigator.of(context).pop(const ToggleDoneChoice()),
        ),
      ],
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, this.detail, this.color, this.selected = false, required this.onPressed});
  final Widget icon;
  final String label;
  final String? detail;
  final Color? color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: DsGeom.row),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: DsStyle.ui(DsText.body, color: color ?? (selected ? Ds.hi : Ds.soft), weight: selected ? FontWeight.w600 : FontWeight.w400),
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(detail!, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                      ),
                  ],
                ),
              ),
              if (selected) Icon(LucideIcons.check, size: 14, color: Ds.mid),
            ],
          ),
        ),
      );
}
