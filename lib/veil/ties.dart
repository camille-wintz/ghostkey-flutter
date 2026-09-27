import '../server/dto/bible.dart';

/// A tie as the page draws it: the card on the roster, and how it is tied.
typedef ResolvedTie = ({BibleEntity entity, String relation});

// One card's ties, whoever wrote them — the desk's `useEntityTies`
// (ghost-key src/veil/tasks/world-bible/hooks/useEntityTies.ts).
//
// The author's list ([BibleEntity.ties]) is THE list once it exists; before
// that the page shows the dossier's, which the next dossier run rewrites.
// The first edit copies what is on screen into the author's list, so adding
// one tie never silently drops the dossier's others — and from then on no
// run touches it. Every edit writes the whole list (the server's PATCH
// replaces it), off the card as the server last answered.
//
// Ties resolve to cards on the roster: a tie to a card deleted or hidden
// since has no page to open, so it is not shown.

/// [entity]'s ties resolved against [entities]: the author's list when there
/// is one (by id), the dossier's [dossierTies] when not (by key).
List<ResolvedTie> resolveTies(BibleEntity entity, List<DossierTie> dossierTies, List<BibleEntity> entities) {
  final visible = entities.where((e) => !e.hidden).toList();
  if (entity.ties case final authored?) {
    return [
      for (final t in authored)
        if (visible.where((e) => e.id == t.entityId).firstOrNull case final tied?) (entity: tied, relation: t.relation),
    ];
  }
  return [
    for (final t in dossierTies)
      if (visible.where((e) => e.key == t.key).firstOrNull case final tied?) (entity: tied, relation: t.relation),
  ];
}

/// Cards that could be tied: every other card on the roster not tied yet,
/// by name.
List<BibleEntity> tieCandidates(BibleEntity entity, List<ResolvedTie> ties, List<BibleEntity> entities) {
  final tied = {for (final t in ties) t.entity.id};
  return entities.where((e) => !e.hidden && e.id != entity.id && !tied.contains(e.id)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// The list on screen as the wire's, ready to be edited and written whole.
List<BibleEntityTie> tiesToWrite(List<ResolvedTie> ties) =>
    [for (final t in ties) BibleEntityTie(entityId: t.entity.id, relation: t.relation)];
