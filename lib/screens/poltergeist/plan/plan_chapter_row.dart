import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/press.dart';
import 'plan_action_pill.dart';
import 'plan_chapter_editor.dart';

/// A row is one ruled line of the ledger — 44px, like every row in the house.
/// It only grows past that when it has something to say: evidence waiting on
/// a Confirm, a chapter that vanished, or the notes editor opened. Row tint:
/// an action the reconciler thinks is done is lit in the accent — the
/// ledger's "waiting on you"; a planned delete smolders red; a chapter that
/// vanished without one goes grey.
class PlanChapterRow extends StatelessWidget {
  const PlanChapterRow({
    super.key,
    required this.chapter,
    required this.words,
    required this.expanded,
    required this.frozen,
    required this.inFolder,
    required this.last,
    required this.onToggleExpand,
    required this.onPill,
    required this.onNotes,
    required this.onConfirm,
    required this.onRemove,
  });

  final PlanChapter chapter;

  /// The chapter's words, from the tree; null on a missing row.
  final int? words;
  final bool expanded;

  /// A seed or reconcile write is in flight — the board is read-only so the
  /// two writers can't race.
  final bool frozen;
  final bool inFolder;
  final bool last;
  final VoidCallback onToggleExpand;
  final VoidCallback onPill;
  final ValueChanged<String> onNotes;
  final VoidCallback onConfirm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final evidence = readyEvidence(chapter);
    final (Color edge, Color? wash) = chapter.missing
        ? (Ds.faint.withValues(alpha: 0.6), Ds.veil)
        : chapter.pending?.ready == true
            ? (Ds.accent, Ds.accentMix(7))
            : chapter.action == PlanActionKind.delete
                ? (Ds.destructive.withValues(alpha: 0.4), Ds.destructive.withValues(alpha: 0.03))
                : (const Color(0x00000000), null);
    final aside = evidence != null
        ? (text: evidence, color: Ds.accent, action: 'Confirm', onAction: onConfirm)
        : chapter.missing
            ? (text: 'No longer in the manuscript.', color: Ds.low, action: 'Remove', onAction: onRemove)
            : null;

    return Container(
      decoration: BoxDecoration(
        color: wash,
        border: Border(
          left: BorderSide(color: edge, width: 2),
          bottom: last ? BorderSide.none : BorderSide(color: Ds.accentMix(7)),
        ),
      ),
      padding: EdgeInsets.only(left: inFolder ? 10 : 4, right: inFolder ? 12 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: DsGeom.row,
            child: Row(
              children: [
                Press(
                  onPressed: onToggleExpand,
                  semanticLabel: '${expanded ? 'Collapse' : 'Expand'} ${chapter.label}',
                  builder: (context, pressed) => SizedBox(
                    width: 26,
                    height: DsGeom.row,
                    child: Icon(expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: pressed ? Ds.soft : Ds.faint),
                  ),
                ),
                Expanded(
                  child: Press(
                    onPressed: onToggleExpand,
                    builder: (context, pressed) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        chapter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.prose(DsText.prose, color: chapter.missing ? Ds.low : Ds.hi).copyWith(
                          decoration: chapter.missing ? TextDecoration.lineThrough : null,
                          decorationColor: Ds.low,
                        ),
                      ),
                    ),
                  ),
                ),
                if (words != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${formatWords(words!)} w',
                    style: DsStyle.ui(DsText.eyebrow, color: Ds.faint).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
                const SizedBox(width: 10),
                PlanActionPill(chapter: chapter, disabled: frozen, onPressed: onPill),
              ],
            ),
          ),
          if (aside != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 0, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(aside.text, style: DsStyle.ui(DsText.ui, color: aside.color))),
                  const SizedBox(width: 12),
                  Press(
                    onPressed: aside.onAction,
                    enabled: !frozen,
                    semanticLabel: aside.action,
                    builder: (context, pressed) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        aside.action.toUpperCase(),
                        style: DsStyle.ui(DsText.eyebrow, color: pressed ? Ds.hi : aside.color, weight: FontWeight.w600, tracking: 11 * 0.12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (expanded) PlanChapterEditor(key: ValueKey('notes-${chapter.id}'), chapter: chapter, onNotes: onNotes, disabled: frozen),
        ],
      ),
    );
  }
}
