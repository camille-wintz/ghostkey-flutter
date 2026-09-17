import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';
import '../add_button.dart';

/// The board's toolbar: the shape of what you're looking at, and the controls
/// that act on the whole page — put every section away at once, or start a
/// chapter at the end of the manuscript. The book's name and its words sit in
/// the room's title bar above; a check in flight is said there too.
class PlanBoardHeader extends StatelessWidget {
  const PlanBoardHeader({
    super.key,
    required this.chapterCount,
    required this.folderCount,
    required this.allCollapsed,
    required this.onToggleAll,
    required this.onAddChapter,
    required this.addDisabled,
  });

  final int chapterCount;
  final int folderCount;

  /// Every folder is shut, so the one control offers the other direction.
  final bool allCollapsed;
  final VoidCallback onToggleAll;
  final VoidCallback onAddChapter;
  final bool addDisabled;

  @override
  Widget build(BuildContext context) {
    final shape = [
      '$chapterCount ${chapterCount == 1 ? 'chapter' : 'chapters'}',
      if (folderCount > 0) '$folderCount ${folderCount == 1 ? 'folder' : 'folders'}',
    ].join(' · ');

    return Container(
      constraints: const BoxConstraints(minHeight: DsGeom.row),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shape.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 11 * 0.12)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          if (folderCount > 0) ...[
            const SizedBox(width: 10),
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
          ],
          const SizedBox(width: 10),
          AddButton(label: 'Add a chapter', disabled: addDisabled, onPressed: onAddChapter),
        ],
      ),
    );
  }
}
