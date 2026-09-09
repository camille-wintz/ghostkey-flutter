import 'package:flutter/material.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../ui/press.dart';
import '../add_button.dart';
import '../page_header.dart';

/// The board holds itself against the manuscript on its own, so the header
/// reports only the shape of what you're looking at — and, while a check is
/// running, that one is. Its controls act on the whole page: put every
/// section away at once, or start a chapter at the end of the manuscript.
class PlanBoardHeader extends StatelessWidget {
  const PlanBoardHeader({
    super.key,
    required this.chapterCount,
    required this.folderCount,
    required this.words,
    required this.isReconciling,
    required this.allCollapsed,
    required this.onToggleAll,
    required this.onAddChapter,
    required this.addDisabled,
  });

  final int chapterCount;
  final int folderCount;

  /// The manuscript's words, when the count has landed.
  final int? words;
  final bool isReconciling;

  /// Every folder is shut, so the one control offers the other direction.
  final bool allCollapsed;
  final VoidCallback onToggleAll;
  final VoidCallback onAddChapter;
  final bool addDisabled;

  @override
  Widget build(BuildContext context) {
    final shape = [
      words != null ? '${formatWords(words!)} words' : '$chapterCount chapters',
      if (folderCount > 0) '$folderCount folders',
    ].join(' · ');

    return PageHeader(
      title: 'Chapters',
      metaWidget: isReconciling
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent)),
                const SizedBox(width: 8),
                const PageMeta('Checking'),
              ],
            )
          : PageMeta(shape),
      actions: [
        if (folderCount > 0)
          Press(
            onPressed: onToggleAll,
            semanticLabel: allCollapsed ? 'Expand all' : 'Collapse all',
            builder: (context, pressed) => Container(
              height: DsGeom.ctl,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pressed ? Ds.veil : const Color(0x00000000),
                border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: Text(
                allCollapsed ? 'EXPAND' : 'COLLAPSE',
                style: DsStyle.ui(DsText.eyebrow, color: Ds.soft, weight: FontWeight.w600, tracking: DsTracking.pill),
              ),
            ),
          ),
        AddButton(label: 'Add a chapter', disabled: addDisabled, onPressed: onAddChapter),
      ],
    );
  }
}
