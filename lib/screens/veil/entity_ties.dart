import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/text.dart';
import '../../veil/entity_writes.dart';
import '../../veil/roster.dart';
import '../../veil/ties.dart';
import 'add_tie_sheet.dart';
import 'entity_screen.dart';
import 'tie_card.dart';
import 'veil_section.dart';

/// Who and what this entity is bound to. Whose list it is, and how it
/// resolves to cards on the roster, is `lib/veil/ties.dart`: the dossier's
/// ties until the author touches them, the author's from then on. A tie to a
/// card hidden or renamed away has no page, so it is not drawn.
///
/// READING, a tap opens that entity's page on top of this one, and the page
/// leaves the band out when nothing is tied ([hasContent]). EDITING, the band
/// is always there: each tie can be removed, and Add tie picks a card and
/// says how they are tied. The phone web's `EntityTies.tsx`.
class EntityTies extends ConsumerStatefulWidget {
  const EntityTies({
    super.key,
    required this.projectId,
    required this.entity,
    required this.entities,
    required this.dossierTies,
    required this.editing,
    required this.seriesId,
  });

  final String projectId;
  final BibleEntity entity;

  /// The whole roster, hidden cards included — they resolve to nothing.
  final List<BibleEntity> entities;
  final List<DossierTie> dossierTies;
  final bool editing;
  final String? seriesId;

  /// Whether the page draws the band at all.
  static bool hasContent(
    BibleEntity entity,
    List<DossierTie> dossierTies,
    List<BibleEntity> entities, {
    required bool editing,
  }) =>
      editing || resolveTies(entity, dossierTies, entities).isNotEmpty;

  @override
  ConsumerState<EntityTies> createState() => _EntityTiesState();
}

class _EntityTiesState extends ConsumerState<EntityTies> {
  bool _saving = false;
  bool _failed = false;

  /// Every edit writes the whole list, built from what is on screen. A
  /// refusal is said under the list rather than thrown, so the add sheet
  /// closes either way.
  Future<void> _write(List<BibleEntityTie> next) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await editEntity(ref, widget.projectId, widget.entity.id, ties: next);
    } catch (e) {
      debugPrint('[veil:ties] save failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ties = resolveTies(widget.entity, widget.dossierTies, widget.entities);
    final candidates = tieCandidates(widget.entity, ties, widget.entities);
    final editing = widget.editing;

    return VeilSection(
      title: 'Ties',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tie) in ties.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: TieCard(
                entity: tie.entity,
                relation: tie.relation,
                seriesId: widget.seriesId,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => EntityScreen(entityKey: tie.entity.key)),
                ),
                onRemove: editing
                    ? () => _write([
                          for (final t in tiesToWrite(ties))
                            if (t.entityId != tie.entity.id) t,
                        ])
                    : null,
                disabled: _saving,
              ),
            ),
          if (editing && _failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: UiText('That did not save. Try again.', step: DsText.ui, color: Ds.destructive),
            ),
          if (editing)
            Padding(
              padding: EdgeInsets.only(top: ties.isNotEmpty ? 12 : 0),
              child: Row(
                children: [
                  GkButton(
                    label: 'Add tie',
                    variant: ButtonVariant.outline,
                    leading: Icon(LucideIcons.plus, size: 16, color: Ds.soft),
                    disabled: candidates.isEmpty,
                    onPressed: () => showAddTieSheet(
                      context,
                      name: titleCase(widget.entity.name),
                      candidates: candidates,
                      seriesId: widget.seriesId,
                      onAdd: (entityId, relation) => _write([
                        ...tiesToWrite(ties),
                        BibleEntityTie(entityId: entityId, relation: relation.trim()),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
