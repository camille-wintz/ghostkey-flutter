import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';
import '../phantom/chat_markdown.dart';

/// The dossier as the reading page shows it: the stale notice, the card's one
/// dossier text ([BibleEntity.notes], the author's and the model's words
/// alike) as markdown with its `## ` sections as titles, then this book's
/// chapter-by-chapter timeline and where the reading came from. Edit mode
/// does not draw it — the text is written on its own screen
/// (`DossierEditorScreen`). Nothing here switches on a section title: the
/// headings are whoever wrote them's choice, and a client that recognised
/// particular ones would re-impose the fixed field list the pipeline
/// deliberately doesn't have.
///
/// The phone web's twin is ghost-key src/mobile/rooms/veil/DossierBody.tsx.
class DossierBody extends StatelessWidget {
  const DossierBody({super.key, required this.notes, required this.dossier});

  /// The card's dossier text. Empty draws nothing.
  final String notes;

  /// The generated half, when one has been written.
  final Dossier? dossier;

  @override
  Widget build(BuildContext context) {
    final dossier = this.dossier;
    final text = notes.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dossier != null && dossier.stale) const DossierStaleNotice(editing: false),
        if (text.isNotEmpty) ChatMarkdown(text, headings: MarkdownHeadings.large),
        if (dossier != null) ..._generated(dossier),
      ],
    );
  }

  List<Widget> _generated(Dossier dossier) {
    final used = dossier.chaptersUsed.length;
    return [
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
        // Where the reading came from, so the author can tell a thin dossier
        // from a thorough one without reading it twice.
        Text(
          'Read from ${chapterCount(used)} of mentions${dossier.truncated ? ' · some passages trimmed to fit' : ''}',
          style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
        ),
    ];
  }
}

/// A chapter the dossier read has changed since. Reading, it says where the
/// update is; editing, the update is right under it.
class DossierStaleNotice extends StatelessWidget {
  const DossierStaleNotice({super.key, required this.editing});
  final bool editing;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Ds.attentionMix(6),
          border: Border.all(color: Ds.attentionMix(25)),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Text(
          editing
              ? 'A chapter this dossier read has changed since it was written.'
              : 'A chapter this dossier read has changed since it was written. Update it in Edit.',
          style: DsStyle.ui(DsText.ui, color: Ds.attention300),
        ),
      );
}
