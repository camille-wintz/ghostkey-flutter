import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../veil/roster.dart';
import 'veil_section.dart';

/// Where this entity stands across the series, one line per book. Only for
/// an actual series — for a standalone it would restate the chapter count
/// above it. Books the entity never appears in are listed too: "not in book
/// 3 yet" is something the author wants to see, and an absent row would
/// read as "unknown". No Open button — that opens Mara, a desktop room.
class EntityBooks extends StatelessWidget {
  const EntityBooks({super.key, required this.entity, required this.projectId});
  final BibleEntity entity;
  final String projectId;

  @override
  Widget build(BuildContext context) => VeilSection(
        title: 'Across the series',
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Column(
            children: [
              for (final (i, book) in entity.books.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
                  child: _BookRow(book: book, here: book.projectId == projectId),
                ),
            ],
          ),
        ),
      );
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.book, required this.here});
  final BibleEntityBook book;
  final bool here;

  @override
  Widget build(BuildContext context) {
    final standing = book.mentionCount > 0
        ? [
            chapterCount(book.mentionCount),
            if (book.firstAppearance != null) 'first in ${chapterLabel(book.firstAppearance!)}',
          ].join(' · ')
        : 'not yet';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              style: DsStyle.ui(DsText.body, color: here ? Ds.ink : Ds.mid),
              children: [
                TextSpan(text: book.title),
                if (here) TextSpan(text: ' · this book', style: DsStyle.ui(DsText.ui, color: Ds.faint)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(standing, style: DsStyle.ui(DsText.ui, color: book.mentionCount > 0 ? Ds.soft : Ds.faint)),
      ],
    );
  }
}
