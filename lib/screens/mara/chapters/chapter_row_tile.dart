import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// One chapter in a Chapters list — the book's, a proposal's, or a changeset
/// laid over the book: its number, its title, a measure at the end, and what
/// it is against the book as a dot or a word.
class ChapterRowTile extends StatelessWidget {
  const ChapterRowTile({
    super.key,
    required this.title,
    required this.onTap,
    this.number,
    this.measure,
    this.dot,
    this.badge,
    this.badgeColor,
    this.nested = false,
    this.dimmed = false,
    this.tint,
  });

  final String title;
  final VoidCallback? onTap;
  final int? number;
  final String? measure;

  /// A status mark before the title.
  final Color? dot;

  /// A status word after the title ("removed", "new").
  final String? badge;
  final Color? badgeColor;

  /// Inside a part.
  final bool nested;

  /// On its way out, or skipped.
  final bool dimmed;

  /// A wash for a row the book does not have yet.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final named = title.trim().isNotEmpty;
    return Press(
      onPressed: onTap,
      semanticLabel: [if (number != null) 'Chapter $number', named ? title : 'Untitled chapter', ?badge].join(', '),
      builder: (context, pressed) => Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: DsGeom.row),
          padding: EdgeInsets.fromLTRB(nested ? 28 : 12, 10, 12, 10),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : (tint ?? const Color(0x00000000)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                child: dot == null
                    ? null
                    : Center(
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                      ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  number == null ? '' : '$number',
                  style: DsStyle.ui(DsText.ui, color: Ds.faint).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(
                child: Text(
                  named ? title : 'Untitled chapter',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DsStyle.prose(DsText.body, color: named ? Ds.ink : Ds.faint),
                ),
              ),
              if (badge case final badge?) ...[
                const SizedBox(width: 8),
                Text(badge.toUpperCase(), style: DsStyle.eyebrow(color: badgeColor ?? Ds.mid, weight: FontWeight.w600)),
              ],
              if (measure case final measure?) ...[
                const SizedBox(width: 10),
                Text(
                  measure,
                  style: DsStyle.ui(DsText.ui, color: Ds.low).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
