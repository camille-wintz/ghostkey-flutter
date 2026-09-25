import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/notice_modal.dart';
import '../../ui/state_screen.dart';
import '../../veil/entity_writes.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import '../project/project_root.dart';
import 'dossier_glance.dart';
import 'entity_actions_sheet.dart';
import 'entity_appearance.dart';
import 'entity_books.dart';
import 'entity_dossier.dart';
import 'entity_facts.dart';
import 'entity_gallery.dart';
import 'entity_gmc.dart';
import 'entity_header.dart';
import 'entity_hero_portrait.dart';
import 'entity_notes.dart';
import 'entity_presence.dart';
import 'entity_text_sheet.dart';
import 'entity_ties.dart';
import 'veil_header.dart';

/// One entity as a page, pushed on the project navigator: the desktop's
/// right column under its left column, in the desktop's order — header,
/// portrait, facts, presence, glance, appearance, pictures, dossier, ties,
/// books, notes. Everything is derived from the two cached reads; the dossier is
/// the one thing the page will build, and the author's own fields — the
/// name, the GMC, the appearance, the notes, hidden — the ones it writes.
///
/// Addressed by key rather than handed the card: a run that lands while the
/// page is open re-derives the roster, and a page holding a stale card would
/// keep drawing yesterday's counts. Once found, the card is followed by its
/// id, because a rename changes the key and the page should stay on it.
class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen({super.key, required this.entityKey});
  final String entityKey;

  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  bool _leaving = false;
  String? _entityId;

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
    final entities = bible.value?.entities ?? const <BibleEntity>[];
    final entity = entities
        .where((e) => !e.hidden && (_entityId != null ? e.id == _entityId : e.key == widget.entityKey))
        .firstOrNull;
    _entityId ??= entity?.id;

    if (entity == null) {
      if (bible.hasValue) _leave();
      return const StateScreen(spinner: true, message: 'Opening…');
    }

    final seriesId = bible.value?.seriesId;
    final dossier = ref.watch(dossiersProvider(projectId)).value?[entity.key];
    final project = ref.watch(projectProvider(projectId)).value;
    final chapters = project != null ? chaptersInTree(project.chapters) : const <DocumentSummary>[];

    final sections = <Widget>[
      if (EntityHeader.hasContent(entity)) EntityHeader(entity: entity),
      if (entity.imageAssetId != null) EntityHeroPortrait(seriesId: seriesId, assetId: entity.imageAssetId!),
      EntityFacts(entity: entity),
      if (chapters.isNotEmpty) EntityPresence(entity: entity, chapters: chapters),
      if (entity.type == BibleEntityType.character)
        EntityGmc(
          entity: entity,
          glance: dossier?.glance ?? const [],
          onEdit: (label, current) => _editGmc(projectId, entity, label, current),
          onKeepAll: (cells) => _write(projectId, entity, gmc: cells),
        )
      else if (dossier != null && dossier.glance.isNotEmpty)
        DossierGlance(glance: dossier.glance),
      EntityAppearance(
        entity: entity,
        dossier: dossier,
        onEdit: () => _editAppearance(projectId, entity, dossier),
        onKeep: () => _write(projectId, entity, description: dossier?.appearance.trim()),
      ),
      if (entity.images.isNotEmpty) EntityGallery(images: entity.images, seriesId: seriesId),
      EntityDossier(projectId: projectId, entity: entity, dossier: dossier, hasChapters: chapters.isNotEmpty),
      if (dossier != null && dossier.ties.isNotEmpty)
        EntityTies(ties: dossier.ties, entities: bible.value!.entities, seriesId: seriesId),
      if (entity.books.length >= 2) EntityBooks(entity: entity, projectId: projectId),
      EntityNotes(notes: entity.notes, onEdit: () => _editNotes(projectId, entity)),
    ];

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VeilHeader(
              entity: entity,
              onBack: () => Navigator.of(context).pop(),
              onMore: () => showEntityActions(
                context,
                name: titleCase(entity.name),
                onRename: () => _rename(projectId, entity),
                onHide: () => _write(projectId, entity, hidden: true),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
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

  /// A one-tap write (Keep, Hide). A failure is said in a notice, since there
  /// is no sheet up to hold it; a hidden card leaves the page on its own.
  Future<void> _write(
    String projectId,
    BibleEntity entity, {
    String? description,
    Map<String, String>? gmc,
    bool? hidden,
  }) async {
    try {
      await editEntity(ref, projectId, entity.id, description: description, gmc: gmc, hidden: hidden);
    } catch (e) {
      if (!mounted) return;
      unawaited(showNoticeModal(
        context,
        eyebrow: 'Veil',
        title: 'That did not save',
        action: 'Got it',
        children: [NoticeText(messageFor(e))],
      ));
    }
  }

  void _rename(String projectId, BibleEntity entity) => showEntityTextSheet(
        context,
        eyebrow: 'Rename',
        initial: entity.name,
        placeholder: 'Name',
        multiline: false,
        allowEmpty: false,
        onSave: (value) => editEntity(ref, projectId, entity.id, name: value),
      );

  void _editNotes(String projectId, BibleEntity entity) => showEntityTextSheet(
        context,
        eyebrow: 'Your notes',
        trailing: titleCase(entity.name),
        initial: entity.notes,
        placeholder: EntityNotes.placeholder,
        onSave: (value) => editEntity(ref, projectId, entity.id, notes: value),
      );

  void _editAppearance(String projectId, BibleEntity entity, Dossier? dossier) => showEntityTextSheet(
        context,
        eyebrow: 'Physical description',
        trailing: titleCase(entity.name),
        initial: entity.description.trim().isNotEmpty ? entity.description : (dossier?.appearance ?? ''),
        placeholder: 'How they look, in your words.',
        onSave: (value) => editEntity(ref, projectId, entity.id, description: value),
      );

  void _editGmc(String projectId, BibleEntity entity, String label, String current) => showEntityTextSheet(
        context,
        eyebrow: label,
        trailing: titleCase(entity.name),
        initial: current,
        hint: 'Leave it empty to clear your answer.',
        onSave: (value) => editEntity(ref, projectId, entity.id, gmc: {label: value}),
      );
}
