import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/notice_modal.dart';
import '../../ui/state_screen.dart';
import '../../server/bible/api.dart';
import '../../veil/entity_writes.dart';
import '../../veil/id_card/id_card.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import '../project/project_root.dart';
import 'dossier_editor_screen.dart';
import 'dossier_glance.dart';
import 'entity_actions_sheet.dart';
import 'entity_appearance.dart';
import 'entity_appearance_lede.dart';
import 'entity_books.dart';
import 'entity_dossier.dart';
import 'entity_facts.dart';
import 'entity_gallery.dart';
import 'entity_gmc_view.dart';
import 'entity_header.dart';
import 'entity_hero_portrait.dart';
import 'entity_interview_sheet.dart';
import 'entity_pictures.dart';
import 'entity_presence.dart';
import 'entity_text_sheet.dart';
import 'entity_ties.dart';
import 'gmc_editor_screen.dart';
import 'id_card_sheet.dart';
import 'veil_header.dart';
import 'veil_section.dart';

/// One entity as a page, pushed on the project navigator: the desktop's
/// right column under its left column, in the desktop's order — header,
/// portrait, facts, presence, glance, appearance, pictures, dossier, ties,
/// books. Everything is derived from the two cached reads; the dossier is
/// the one thing the page will build, and the author's own fields — the
/// name, the GMC, the appearance, the dossier text, hidden, the portrait and
/// the gallery — the ones it writes.
///
/// Addressed by key rather than handed the card: a run that lands while the
/// page is open re-derives the roster, and a page holding a stale card would
/// keep drawing yesterday's counts. Once found, the card is followed by its
/// id, because a rename changes the key and the page should stay on it.
///
/// Two modes, as on the desk. READING (the page opens on it) shows the card
/// as a dossier: the description as a lede, the GMC answers alone, the
/// dossier text as prose, the strip through the book — nothing on it changes
/// the card. EDITING drops what only reads (aliases, source, the strip) and
/// puts the writable things in the same places: the portrait as its own
/// door, the GMC and the dossier as buttons onto their own screens, the
/// description (which can be written from the portrait), the gallery with
/// its Add and its drag, the interview and the runs, the ties, and the
/// card's own actions. Every field saves from its sheet or screen, so Done only
/// goes back to reading. The phone web's `EntityPage.tsx`.
class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen({super.key, required this.entityKey});
  final String entityKey;

  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  bool _leaving = false;
  String? _entityId;
  bool _editing = false;
  bool _describing = false;
  bool _portraitBusy = false;
  bool _galleryBusy = false;

  /// The character's ID card, made on the first open and kept for the page's
  /// life, so a second open shows the same card rather than a new line.
  IdCard? _idCard;

  @override
  void dispose() {
    _idCard?.dispose();
    super.dispose();
  }

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

    final glance = dossier?.glance ?? const <DossierGlanceItem>[];
    final dossierTies = dossier?.ties ?? const <DossierTie>[];
    final editing = _editing;
    final sections = <Widget>[
      if (EntityHeader.hasContent(entity, editing: editing)) EntityHeader(entity: entity, editing: editing),
      if (entity.imageAssetId != null || editing)
        EntityHeroPortrait(
          seriesId: seriesId,
          assetId: entity.imageAssetId,
          busy: _portraitBusy,
          onEdit: editing
              ? () => editPortrait(
                    context,
                    ref,
                    projectId: projectId,
                    entity: entity,
                    name: titleCase(entity.name),
                    prompt: entity.description.trim().isNotEmpty ? entity.description : (dossier?.appearance ?? ''),
                    onBusy: (busy) => mounted ? setState(() => _portraitBusy = busy) : null,
                  )
              : null,
        ),
      if (!editing && EntityAppearanceLede.hasContent(entity)) EntityAppearanceLede(entity: entity),
      if (EntityFacts.hasContent(entity, editing: editing)) EntityFacts(entity: entity, editing: editing),
      if (!editing && chapters.isNotEmpty) EntityPresence(entity: entity, chapters: chapters),
      if (entity.type == BibleEntityType.character)
        if (editing)
          VeilSection(
            title: 'Goal, motivation, conflict',
            child: Align(
              alignment: Alignment.centerLeft,
              child: GkButton(
                label: 'Edit GMC',
                leading: Icon(LucideIcons.penLine, size: 16, color: Ds.accent),
                onPressed: () => _editGmc(projectId, entity, glance),
              ),
            ),
          )
        else if (EntityGmcView.hasContent(entity, glance))
          EntityGmcView(entity: entity, glance: glance)
        else
          const SizedBox.shrink()
      else if (glance.isNotEmpty)
        DossierGlance(glance: glance),
      if (editing)
        EntityAppearance(
          entity: entity,
          dossier: dossier,
          onEdit: () => _editAppearance(projectId, entity, dossier),
          onKeep: () => _write(projectId, entity, description: dossier?.appearance.trim()),
          onDescribe: entity.imageAssetId != null ? () => _describe(projectId, entity) : null,
          describing: _describing,
        ),
      if (entity.images.isNotEmpty || editing)
        EntityGallery(
          images: entity.images,
          seriesId: seriesId,
          adding: _galleryBusy,
          onAdd: editing
              ? () => addToGallery(
                    context,
                    ref,
                    projectId: projectId,
                    entity: entity,
                    onBusy: (busy) => mounted ? setState(() => _galleryBusy = busy) : null,
                  )
              : null,
          onReorder: editing
              ? (ids) => orderGallery(context, ref, projectId: projectId, entityId: entity.id, itemIds: ids)
              : null,
          onSetPortrait: editing
              ? (image) => setPortraitFrom(context, ref, projectId: projectId, entityId: entity.id, image: image)
              : null,
          onRemove: editing
              ? (image) => removeFromCard(context, ref, projectId: projectId, entityId: entity.id, image: image)
              : null,
        ),
      EntityDossier(
        projectId: projectId,
        entity: entity,
        dossier: dossier,
        hasChapters: chapters.isNotEmpty,
        editing: editing,
        onEdit: () => _editDossier(projectId, entity),
        onCreate: () {
          setState(() => _editing = true);
          _editDossier(projectId, entity);
        },
        onInterview: () => showEntityInterview(context, projectId: projectId, entity: entity),
      ),
      if (EntityTies.hasContent(entity, dossierTies, entities, editing: editing))
        EntityTies(
          projectId: projectId,
          entity: entity,
          entities: entities,
          dossierTies: dossierTies,
          editing: editing,
          seriesId: seriesId,
        ),
      if (entity.books.length >= 2) EntityBooks(entity: entity, projectId: projectId),
    ].where((w) => w is! SizedBox).toList();

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VeilHeader(
              entity: entity,
              onBack: () => Navigator.of(context).pop(),
              editing: editing,
              onEdit: () => setState(() => _editing = true),
              onDone: () => setState(() => _editing = false),
              onMore: () => showEntityActions(
                context,
                name: titleCase(entity.name),
                onRename: () => _rename(projectId, entity),
                onHide: () => _write(projectId, entity, hidden: true),
              ),
              besideEdit: entity.type == BibleEntityType.character && !editing
                  ? GkButton(
                      label: 'ID card',
                      variant: ButtonVariant.outline,
                      leading: Icon(LucideIcons.idCard, size: 15, color: Ds.soft),
                      onPressed: () => _openIdCard(projectId, seriesId, entity),
                    )
                  : null,
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

  void _openIdCard(String projectId, String? seriesId, BibleEntity entity) {
    final assetId = entity.imageAssetId;
    final card = _idCard ??= IdCard(
      name: titleCase(entity.name),
      ask: (avoid) => entityTagline(projectId, entity.id, avoid: avoid),
      // Read when the card first opens: a portrait changed after that is
      // not on this page's card.
      portrait: () async =>
          seriesId == null || seriesId.isEmpty || assetId == null ? null : await getSeriesAsset(seriesId, assetId),
    );
    card.name = titleCase(entity.name);
    showIdCardSheet(context, card);
  }

  /// A one-tap write (Keep, Hide). A failure is said in a notice, since there
  /// is no sheet up to hold it; a hidden card leaves the page on its own.
  Future<void> _write(
    String projectId,
    BibleEntity entity, {
    String? description,
    bool? hidden,
  }) async {
    try {
      await editEntity(ref, projectId, entity.id, description: description, hidden: hidden);
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

  /// The description written from the card's portrait, saved at once: the
  /// author asked for it, and was asked first if it replaces words of theirs.
  Future<void> _describe(String projectId, BibleEntity entity) async {
    if (_describing) return;
    if (entity.description.trim().isNotEmpty) {
      final ok = await showConfirmSheet(
        context,
        eyebrow: 'Physical description',
        title: 'Replace your description?',
        message: "This writes a new description from the portrait. What's there now will be lost.",
        confirmLabel: 'Replace',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _describing = true);
    String? failure;
    try {
      if (await describeFromPortrait(ref, projectId, entity.id) == null) {
        failure = "Couldn't find anyone to describe in that picture.";
      }
    } catch (e) {
      failure = switch (e) {
        ServerError(code: 'no_portrait') => "The portrait couldn't be opened. Try adding it again.",
        _ => messageFor(e),
      };
    } finally {
      if (mounted) setState(() => _describing = false);
    }
    if (failure != null && mounted) {
      unawaited(showNoticeModal(
        context,
        eyebrow: 'Veil',
        title: 'No description',
        action: 'Got it',
        children: [NoticeText(failure)],
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

  /// The dossier text is the card's `notes`: markdown, `## ` for sections,
  /// the same field the dossier job files its prose into. Written on its own
  /// screen, over this page.
  void _editDossier(String projectId, BibleEntity entity) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DossierEditorScreen(
            name: titleCase(entity.name),
            initial: entity.notes,
            onSave: (value) => editEntity(ref, projectId, entity.id, notes: value),
          ),
        ),
      );

  void _editAppearance(String projectId, BibleEntity entity, Dossier? dossier) => showEntityTextSheet(
        context,
        eyebrow: 'Physical description',
        trailing: titleCase(entity.name),
        initial: entity.description.trim().isNotEmpty ? entity.description : (dossier?.appearance ?? ''),
        placeholder: 'How they look, in your words.',
        onSave: (value) => editEntity(ref, projectId, entity.id, description: value),
      );

  /// Only the cells that changed are written, so an answer edited on the
  /// desk meanwhile is not undone.
  void _editGmc(String projectId, BibleEntity entity, List<DossierGlanceItem> glance) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GmcEditorScreen(
            name: titleCase(entity.name),
            authored: entity.gmc,
            glance: glance,
            onSave: (cells) => editEntity(ref, projectId, entity.id, gmc: cells),
          ),
        ),
      );
}
