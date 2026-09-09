import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/providers.dart';
import '../../ui/state_screen.dart';
import '../../veil/providers.dart';
import '../project/project_root.dart';
import 'dossier_glance.dart';
import 'entity_appearance.dart';
import 'entity_books.dart';
import 'entity_dossier.dart';
import 'entity_facts.dart';
import 'entity_header.dart';
import 'entity_hero_portrait.dart';
import 'entity_notes.dart';
import 'entity_presence.dart';
import 'entity_ties.dart';
import 'veil_header.dart';

/// One entity as a page, pushed on the project navigator: the desktop's
/// right column under its left column, in the desktop's order — header,
/// portrait, facts, presence, glance, appearance, dossier, ties, books,
/// notes. Everything is derived from the two cached reads; the dossier is
/// the one thing the page will build.
///
/// Addressed by key rather than handed the card: a run that lands while the
/// page is open re-derives the roster, and a page holding a stale card would
/// keep drawing yesterday's counts.
class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen({super.key, required this.entityKey});
  final String entityKey;

  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  bool _leaving = false;

  /// The key may go stale under this page — renamed, hidden, or dropped by a
  /// rebuild. Back to the roster rather than a blank page. Safe only once the
  /// bible has answered: an unloaded bible has no entities either.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ProjectScope.of(context);
    final bible = ref.watch(bibleProvider(projectId));
    final entity = bible.value?.entities.where((e) => e.key == widget.entityKey && !e.hidden).firstOrNull;

    if (entity == null) {
      if (bible.hasValue) _leave();
      return const StateScreen(spinner: true, message: 'Opening…');
    }

    final seriesId = bible.value?.seriesId;
    final dossier = ref.watch(dossiersProvider(projectId)).value?[entity.key];
    final project = ref.watch(projectProvider(projectId)).value;
    final chapters = project != null ? chaptersInTree(project.chapters) : const <DocumentSummary>[];

    final sections = <Widget>[
      EntityHeader(entity: entity),
      if (entity.imageAssetId != null) EntityHeroPortrait(seriesId: seriesId, assetId: entity.imageAssetId!),
      EntityFacts(entity: entity),
      if (chapters.isNotEmpty) EntityPresence(entity: entity, chapters: chapters),
      if (dossier != null && dossier.glance.isNotEmpty) DossierGlance(glance: dossier.glance),
      if (entity.description.isNotEmpty || (dossier?.appearance.isNotEmpty ?? false))
        EntityAppearance(entity: entity, dossier: dossier),
      EntityDossier(projectId: projectId, entity: entity, dossier: dossier, hasChapters: chapters.isNotEmpty),
      if (dossier != null && dossier.ties.isNotEmpty)
        EntityTies(ties: dossier.ties, entities: bible.value!.entities, seriesId: seriesId),
      if (entity.books.length >= 2) EntityBooks(entity: entity, projectId: projectId),
      if (entity.notes.trim().isNotEmpty) EntityNotes(notes: entity.notes),
    ];

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VeilHeader(backLabel: 'Veil', onBack: () => Navigator.of(context).pop(), eyebrow: 'World bible'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                itemCount: sections.length,
                separatorBuilder: (context, i) => const SizedBox(height: 28),
                itemBuilder: (context, i) => sections[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
