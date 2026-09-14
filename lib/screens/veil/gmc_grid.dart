import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';

/// A character's GMC: one hairline-separated row per question, the question
/// and what it asks above its external and internal answers, each side naming
/// itself. A phone is too narrow for the desk's two columns, so the sides
/// stack; a side the excerpts left empty shows a dash rather than vanishing,
/// so the gap reads as a gap.
class GmcGrid extends StatelessWidget {
  const GmcGrid({super.key, required this.rows});
  final List<GmcRow> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Ds.edge,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 1),
                child: Container(
                  color: Ds.surf,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.question, style: DsStyle.prose(DsText.body, color: Ds.accent200)),
                      Text(row.meaning, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                      for (final (side, value) in [('External', row.external), ('Internal', row.internal)]) ...[
                        const SizedBox(height: 10),
                        Text(side.toUpperCase(), style: DsStyle.eyebrow()),
                        const SizedBox(height: 2),
                        Text(
                          value.isEmpty ? '—' : value,
                          style: DsStyle.prose(DsText.body, color: value.isEmpty ? Ds.faint : Ds.ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
