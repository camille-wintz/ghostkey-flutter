import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';

/// A written dossier as the page reads it: the stale notice, the overview,
/// the sections, the chapter-by-chapter timeline, and where it came from.
/// Nothing here switches on a section title — the model chooses them to fit
/// the entity, and a client that recognised particular ones would re-impose
/// the fixed field list the pipeline deliberately doesn't have.
class DossierBody extends StatelessWidget {
  const DossierBody({super.key, required this.dossier});
  final Dossier dossier;

  @override
  Widget build(BuildContext context) {
    final used = dossier.chaptersUsed.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dossier.stale)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Ds.attentionMix(6),
              border: Border.all(color: Ds.attentionMix(25)),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Text(
              'A chapter this dossier read has changed since it was written.',
              style: DsStyle.ui(DsText.ui, color: Ds.attention300),
            ),
          ),
        if (dossier.overview.trim().isNotEmpty)
          Text(dossier.overview.trim(), style: DsStyle.prose(DsText.prose, color: Ds.ink)),
        for (final section in dossier.sections) ...[
          const SizedBox(height: 22),
          Eyebrow(section.title, semibold: false),
          const SizedBox(height: 8),
          _Prose(section.body),
        ],
        if (dossier.timeline.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Eyebrow('Chapter by chapter', semibold: false),
          for (final entry in dossier.timeline) ...[
            const SizedBox(height: 12),
            Text(chapterLabel(entry.chapter), style: DsStyle.ui(DsText.ui, color: Ds.faint)),
            for (final event in entry.events)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(event, style: DsStyle.ui(DsText.body, color: Ds.soft)),
              ),
          ],
        ],
        const SizedBox(height: 18),
        // Where it came from, so the author can tell a thin dossier from a
        // thorough one without reading it twice.
        Text(
          'Written from ${chapterCount(used)} of mentions${dossier.truncated ? ' · some passages trimmed to fit' : ''}',
          style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
        ),
      ],
    );
  }
}

/// Model-written prose, one paragraph per blank line.
class _Prose extends StatelessWidget {
  const _Prose(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, paragraph) in paragraphs.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Text(paragraph, style: DsStyle.prose(DsText.body, color: Ds.soft)),
          ),
      ],
    );
  }
}
