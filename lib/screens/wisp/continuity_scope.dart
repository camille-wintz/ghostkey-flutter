import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// What the plot-hole check reads: one chapter against everything before it,
/// or the whole book — padlocked below Standard. The chapter row opens the
/// chat's chapter sheet (the phone document's ContinuityScope draws the same).
class ContinuityScope extends StatelessWidget {
  const ContinuityScope({
    super.key,
    required this.chapterName,
    required this.onOne,
    required this.onPickChapter,
    required this.onBook,
    required this.bookLocked,
  });

  /// The chapter checked; null when it is the whole book or none is picked.
  final String? chapterName;

  /// Whether one chapter is checked rather than the whole book.
  final bool onOne;
  final VoidCallback onPickChapter;
  final VoidCallback onBook;
  final bool bookLocked;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: DsGeom.ctl,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Ds.surf,
                border: Border.all(color: Ds.edge),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: Row(
                children: [
                  _Segment(label: 'One chapter', on: onOne, onPressed: onOne ? null : onPickChapter),
                  _Segment(label: 'Check whole book', on: !onOne, locked: bookLocked, onPressed: onOne ? onBook : null),
                ],
              ),
            ),
            if (onOne) ...[
              const SizedBox(height: 8),
              Press(
                onPressed: onPickChapter,
                semanticLabel: 'Pick the chapter',
                builder: (context, pressed) => Container(
                  height: DsGeom.row,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: pressed ? Ds.veil : Ds.panel,
                    border: Border.all(color: Ds.edge),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: UiText(chapterName ?? 'Pick a chapter', step: DsText.ui, color: Ds.ink, maxLines: 1),
                      ),
                      Icon(LucideIcons.chevronRight, size: 16, color: Ds.mid),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, required this.onPressed, this.locked = false});
  final String label;
  final bool on;
  final VoidCallback? onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Press(
          onPressed: onPressed ?? () {},
          semanticLabel: label,
          builder: (context, pressed) => AnimatedContainer(
            duration: DsMotion.duration,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(DsGeom.radius - 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(LucideIcons.lock, size: 12, color: Ds.mid),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.ui(DsText.eyebrow, color: on ? Ds.accent200 : Ds.mid, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
