import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';
import 'dossier_body.dart';
import 'dossier_glance.dart';
import 'entity_appearance_lede.dart';
import 'entity_gmc_view.dart';

/// The card under the interview, filling in as the author answers: each
/// answer is filed where its question pointed and the bible re-read brings it
/// here, so this draws only the card as it now is. Under it, how many of the
/// words are the author's, gold once there are any. The desk's
/// `BibleInterviewSheet`.
class InterviewCardSheet extends StatelessWidget {
  const InterviewCardSheet({super.key, required this.entity, required this.dossier});
  final BibleEntity entity;
  final Dossier? dossier;

  @override
  Widget build(BuildContext context) {
    final glance = dossier?.glance ?? const <DossierGlanceItem>[];
    final words = _wordsIn(entity.notes) + _wordsIn(entity.description);
    final empty = entity.notes.trim().isEmpty && entity.description.trim().isEmpty;
    final isCharacter = entity.type == BibleEntityType.character;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(color: Ds.panel, borderRadius: BorderRadius.circular(DsGeom.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Character sheet'),
          const SizedBox(height: 6),
          Text(titleCase(entity.name), style: DsStyle.prose(DsText.title, color: Ds.hi)),
          if (EntityAppearanceLede.hasContent(entity)) ...[
            const SizedBox(height: 14),
            EntityAppearanceLede(entity: entity),
          ],
          if (isCharacter && EntityGmcView.hasContent(entity, glance)) ...[
            const SizedBox(height: 22),
            EntityGmcView(entity: entity, glance: glance),
          ] else if (!isCharacter && glance.isNotEmpty) ...[
            const SizedBox(height: 22),
            DossierGlance(glance: glance),
          ],
          if (entity.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            DossierBody(notes: entity.notes, dossier: null),
          ],
          if (empty) ...[
            const SizedBox(height: 14),
            Text(
              'Nothing here yet. Each answer lands on this page as you wrote it, and you can edit any of it.',
              style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic, height: 1.55),
            ),
          ],
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$words',
                style: DsStyle.prose(DsText.display, color: words > 0 ? Ds.attention300 : Ds.hi).copyWith(
                  shadows: words > 0 ? [Shadow(color: Ds.attention.withValues(alpha: 0.5), blurRadius: 18)] : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                words == 1 ? 'word, all yours' : 'words, all yours',
                style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Words the author wrote: section titles and the run-in labels the
/// interview files answers under are the question's, not theirs.
int _wordsIn(String text) => text
    .replaceAll(RegExp(r'^#{1,6}\s.*$', multiLine: true), '')
    .replaceAll(RegExp(r'\*\*.+?\*\*'), '')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .length;
