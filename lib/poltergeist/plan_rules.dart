import 'dart:convert';

import '../server/dto/projects.dart';

// The plan is a WORKLIST over the manuscript — one row per chapter carrying a
// pending action — and these rules keep it honest, the desktop's
// core/poltergeist/{plan,reconcile,actions}.ts as far as a phone can follow
// them. Everything here is pure: the manuscript comes in as the chapter tree
// the project fetch already carries, and the clock and the id mint are
// arguments, so the whole file is testable without a device.
//
// What a phone cannot do is read chapter bodies for a minhash fingerprint,
// so the textual measurement (how much of a chapter changed since its action
// was tagged) stays the desktop's. This reconciler settles what the tree
// alone can settle — links, renames, vanished chapters, new chapters, moves,
// and whether an empty chapter has gained words — and carries the desktop's
// last measurement of the rest untouched.

/// What a mutation does to a row (desktop `PlanActionOp`). The first three
/// act on the pending action; the last two set and lift `done`.
enum PlanOp { assign, clear, confirm, done, undone }

class ReconcileResult {
  const ReconcileResult({required this.plan, required this.changed});
  final ProjectPlan plan;

  /// Something moved, so the plan wants writing back. A reconcile that
  /// changed nothing is not a save.
  final bool changed;
}

/// The linked document immediately before this one in manuscript order; null
/// when it is first. The move anchor and the move check must agree on this.
String? prevDocumentId(List<DocumentSummary> docs, String documentId) {
  final i = docs.indexWhere((d) => d.id == documentId);
  return i > 0 ? docs[i - 1].id : null;
}

/// A textual action's anchor: the chapter as the tree describes it now. No
/// fingerprint — the desktop measures churn from nothing against one.
PlanActionAnchor contentAnchor(DocumentSummary doc) => PlanActionAnchor(version: doc.version, words: doc.wordCount);

/// The action a chapter joining the board owes: its line edit, unless the
/// chapter is empty, in which case its write.
PlanAction _joiningAction(DocumentSummary doc, String now) => PlanAction.fresh(
      doc.wordCount == 0 ? PlanActionKind.write : PlanActionKind.lineEdit,
      now,
      anchor: contentAnchor(doc),
    );

/// A fresh plan from the manuscript: one linked row per chapter, each owing
/// its line edit (or its write, when empty). No outline, no model call — a
/// worklist over a manuscript IS its chapter list.
ProjectPlan seedPlan(List<ChaptersListEntry> tree, {required String now, required String Function() newId}) {
  final rows = [
    for (final doc in chaptersInTree(tree))
      PlanChapter.linked(id: newId(), documentId: doc.id, filename: doc.filename, action: _joiningAction(doc, now)),
  ];
  return ProjectPlan.seeded(rows, now);
}

/// Linked rows mirror manuscript order; rows without a link (missing rows)
/// keep their place after the same neighbour they followed.
List<PlanChapter> inManuscriptOrder(List<PlanChapter> chapters, List<DocumentSummary> docs) {
  final unlinkedAfter = <String?, List<PlanChapter>>{};
  final linkedByDocId = <String, PlanChapter>{};
  String? lastLinked;
  for (final row in chapters) {
    final documentId = row.documentId;
    if (documentId != null) {
      linkedByDocId[documentId] = row;
      lastLinked = row.id;
    } else {
      unlinkedAfter.putIfAbsent(lastLinked, () => []).add(row);
    }
  }

  final placed = <String>{};
  final ordered = <PlanChapter>[];
  void push(Iterable<PlanChapter>? rows) {
    for (final row in rows ?? const <PlanChapter>[]) {
      ordered.add(row);
      placed.add(row.id);
    }
  }

  push(unlinkedAfter[null]);
  for (final doc in docs) {
    final row = linkedByDocId[doc.id];
    if (row == null) continue;
    push([row]);
    push(unlinkedAfter[row.id]);
  }
  // Anything left followed a row that no longer exists — keep it, at the end.
  push(chapters.where((c) => !placed.contains(c.id)));
  return ordered;
}

PlanChapter _completes(PlanChapter row, String now) {
  final pending = row.pending;
  if (pending == null) return row;
  return row.copyWith(
    clearAction: true,
    history: [...row.history, PlanHistoryEntry(kind: pending.kind, completedAt: now)],
  );
}

/// Hold the plan against the live manuscript and settle every action the
/// tree has already answered. Deterministic and free, so it runs by itself
/// whenever the board opens or the manuscript moves under it.
///
///  - Pass 1 settles existing links by document id (rename-proof): the row's
///    title follows the chapter; a chapter that vanished completes a planned
///    delete (the row goes with it) and flags any other row `missing`.
///  - Pass 2 adopts: a missing row relinks when a chapter with the same name
///    reappears. A pending write re-anchors on the empty state, so it turns
///    ready while words are on the page.
///  - Pass 3 lists chapters the board has never seen as new rows — this is
///    also how new chapters get pulled in, no re-seed. They owe a line edit,
///    or the write when empty.
///  - Pass 4: a move completes when the chapter's predecessor changed. A
///    textual action with no anchor yet captures one now; one whose chapter
///    hasn't moved is not ready; a write turns ready when the chapter has
///    words. A rewrite or line edit the desktop anchored keeps the desktop's
///    verdict; one this phone anchored reads a moved version as a line edit
///    that looks done, and never as a rewrite that does (churn is the
///    desktop's to measure).
///
/// Nothing here ever un-finishes a done row. Plans of a format this build
/// doesn't write are returned untouched.
ReconcileResult reconcilePlan(
  ProjectPlan plan,
  List<ChaptersListEntry> tree, {
  required String now,
  required String Function() newId,
}) {
  if (plan.formatVersion != planFormatVersion) return ReconcileResult(plan: plan, changed: false);

  final docs = chaptersInTree(tree);
  final docById = {for (final d in docs) d.id: d};
  // Duplicate filenames collapse (first claim wins) — same-named chapters are
  // indistinguishable by name.
  final docByFilename = <String, DocumentSummary>{};
  for (final d in docs) {
    docByFilename.putIfAbsent(d.filename, () => d);
  }

  final claimed = <String>{};
  var rows = <PlanChapter>[];

  // Pass 1: settle existing links.
  for (final row in plan.chapters) {
    final documentId = row.documentId;
    if (documentId == null) {
      rows.add(row);
      continue;
    }
    final doc = docById[documentId];
    if (doc != null && !claimed.contains(doc.id)) {
      claimed.add(doc.id);
      rows.add(row.copyWith(filename: doc.filename, title: doc.filename, missing: false));
    } else if (row.action == PlanActionKind.delete) {
      // The chapter is gone, as planned — row and all.
    } else {
      rows.add(row.copyWith(clearDocument: true, missing: true));
    }
  }

  // Pass 2: adopt by name.
  rows = [
    for (final row in rows)
      if (row.documentId != null) row else _adopt(row, docByFilename, claimed),
  ];

  // Pass 3: chapters the board has never seen join as new rows.
  for (final doc in docs) {
    if (claimed.contains(doc.id)) continue;
    claimed.add(doc.id);
    rows.add(PlanChapter.linked(id: newId(), documentId: doc.id, filename: doc.filename, action: _joiningAction(doc, now)));
  }

  // Pass 4: settle what the tree can answer about each pending action.
  rows = [for (final row in rows) _settle(row, docs, docById, now)];

  final ordered = inManuscriptOrder(rows, docs);
  final changed = _encode(plan.chapters) != _encode(ordered);
  return ReconcileResult(
    plan: changed ? plan.withChapters(ordered, reconciledAt: now) : plan,
    changed: changed,
  );
}

PlanChapter _adopt(PlanChapter row, Map<String, DocumentSummary> docByFilename, Set<String> claimed) {
  final doc = docByFilename[row.title.trim()];
  if (doc == null || claimed.contains(doc.id)) return row;
  claimed.add(doc.id);
  var next = row.copyWith(documentId: doc.id, filename: doc.filename, title: doc.filename, missing: false);
  final pending = next.pending;
  if (pending != null && pending.kind == PlanActionKind.write) {
    // The write plausibly happened, but only the author knows if it's
    // finished. Re-anchor on the pre-write (empty) state with a version no
    // real document carries, so pass 4 flips `ready` while words are on the
    // page.
    next = next.copyWith(pending: pending.copyWith(anchor: const PlanActionAnchor(version: -1, words: 0)));
  }
  return next;
}

PlanChapter _settle(PlanChapter row, List<DocumentSummary> docs, Map<String, DocumentSummary> docById, String now) {
  final pending = row.pending;
  final documentId = row.documentId;
  if (pending == null || documentId == null) return row;
  final doc = docById[documentId];
  if (doc == null) return row;

  if (pending.kind == PlanActionKind.move) {
    return prevDocumentId(docs, doc.id) != pending.anchor.prevDocumentId ? _completes(row, now) : row;
  }
  if (!pending.kind.textual) return row;

  final anchor = pending.anchor;
  if (anchor.version == null) {
    // Anchor never captured (interrupted assign) — the action starts
    // measuring from here.
    return row.copyWith(pending: pending.copyWith(anchor: contentAnchor(doc)));
  }
  if (doc.version == anchor.version) {
    return row.copyWith(pending: pending.copyWith(ready: false, clearEvidence: true));
  }

  final words = doc.wordCount;
  switch (pending.kind) {
    case PlanActionKind.write:
      // The chapter gained words — looks written, but only the author knows
      // if it's finished. A write measures from empty, so churn is whole.
      final ready = words != null && words > 0;
      return row.copyWith(
        pending: pending.copyWith(
          ready: ready,
          clearEvidence: !ready,
          evidence: ready ? PlanActionEvidence(churn: 1, wordsBefore: anchor.words ?? 0, wordsAfter: words) : null,
        ),
      );
    case PlanActionKind.lineEdit:
      // The desktop's churn verdict stands; a phone-anchored line edit reads
      // a moved version as "looks done", which is what any real edit trips.
      if (anchor.fingerprint != null) return row;
      return row.copyWith(pending: pending.copyWith(ready: true, clearEvidence: true));
    case PlanActionKind.rewrite:
      // A rewrite is only ready past a churn floor no word count can stand
      // in for. Nothing to settle here.
      return row;
    case PlanActionKind.move:
    case PlanActionKind.delete:
      return row;
  }
}

String _encode(List<PlanChapter> rows) => jsonEncode(rows.map((r) => r.toJson()).toList());

/// The one place a row's action state changes — the whole [PlanOp]
/// vocabulary, so the board and any other caller never drift on what
/// assigning, confirming or finishing a chapter means. Returns null when the
/// op can't apply to that row (no chapter to act on, nothing ready to
/// confirm).
ProjectPlan? applyPlanOp(
  ProjectPlan plan,
  String rowId,
  PlanOp op, {
  PlanActionKind? kind,
  required List<ChaptersListEntry> tree,
  required String now,
}) {
  final i = plan.chapters.indexWhere((c) => c.id == rowId);
  if (i < 0) return null;
  final row = plan.chapters[i];
  final docs = chaptersInTree(tree);
  final next = switch (op) {
    PlanOp.clear => row.copyWith(clearAction: true),
    PlanOp.assign => _assign(row, kind, docs, now),
    PlanOp.confirm => _confirm(row, docs, now),
    // By hand, from the pill menu — whatever the row still owed is moot.
    PlanOp.done => row.copyWith(clearAction: true, done: true),
    PlanOp.undone => row.copyWith(done: false),
  };
  if (next == null) return null;
  final chapters = List<PlanChapter>.from(plan.chapters);
  chapters[i] = next;
  return plan.withChapters(chapters);
}

PlanActionAnchor _anchorFor(PlanChapter row, PlanActionKind kind, List<DocumentSummary> docs) {
  final documentId = row.documentId!;
  if (kind.textual) {
    final doc = docs.where((d) => d.id == documentId).firstOrNull;
    return doc == null ? PlanActionAnchor.empty : contentAnchor(doc);
  }
  if (kind == PlanActionKind.move) return PlanActionAnchor(prevDocumentId: prevDocumentId(docs, documentId));
  return PlanActionAnchor.empty; // delete: completion is structural
}

PlanChapter? _assign(PlanChapter row, PlanActionKind? kind, List<DocumentSummary> docs, String now) {
  // Every row is a real chapter — every action needs the link.
  if (kind == null || row.documentId == null || row.missing) return null;
  return row.copyWith(pending: PlanAction.fresh(kind, now, anchor: _anchorFor(row, kind, docs)), done: false);
}

PlanChapter? _confirm(PlanChapter row, List<DocumentSummary> docs, String now) {
  final pending = row.pending;
  if (pending == null || !pending.ready) return null;
  final history = [...row.history, PlanHistoryEntry(kind: pending.kind, completedAt: now)];
  // A finished write or rewrite always owes a line edit, anchored on the text
  // as it stands now. The line edit is the last pass: confirming it finishes
  // the chapter.
  final chained = pending.kind.chainsTo;
  final next = row.copyWith(history: history, clearAction: true);
  if (chained != null && row.documentId != null) {
    return next.copyWith(pending: PlanAction.fresh(chained, now, anchor: _anchorFor(row, chained, docs)));
  }
  return pending.kind == PlanActionKind.lineEdit ? next.copyWith(done: true) : next;
}

/// The row's notes, the one always-editable text on it.
ProjectPlan withRowNotes(ProjectPlan plan, String rowId, String notes) =>
    plan.withChapters([for (final c in plan.chapters) c.id == rowId ? c.copyWith(notes: notes) : c]);

/// Only missing rows can leave the board by hand — a linked row would come
/// straight back on the next reconcile.
ProjectPlan? withoutRow(ProjectPlan plan, String rowId) {
  final row = plan.chapters.where((c) => c.id == rowId).firstOrNull;
  if (row == null || !row.missing) return null;
  return plan.withChapters(plan.chapters.where((c) => c.id != rowId).toList());
}

/// How much of the manuscript owes nothing.
class PlanProgress {
  const PlanProgress({required this.clean, required this.total});
  final int clean;
  final int total;

  /// 0–1, for the bar. 0 when there is no plan yet.
  double get fraction => total == 0 ? 0 : clean / total;
}

PlanProgress planProgress(ProjectPlan? plan) {
  final rows = plan?.chapters ?? const <PlanChapter>[];
  return PlanProgress(clean: rows.where((r) => r.action == null && !r.missing).length, total: rows.length);
}

/// Rows owing a given kind.
int owedCount(Iterable<PlanChapter> rows, PlanActionKind kind) => rows.where((r) => r.action == kind).length;

/// Rows owing nothing that nobody has called done, or that are simply not
/// missing — the dashboard's "Clean".
int cleanCount(Iterable<PlanChapter> rows) => rows.where((r) => r.action == null && !r.missing).length;

/// Rows past the last action.
int doneCount(Iterable<PlanChapter> rows) => rows.where((r) => r.action == null && r.done).length;

/// The desktop's `readyEvidence`: what the row says while it waits on a
/// Confirm, or null when nothing is ready.
String? readyEvidence(PlanChapter row) {
  final action = row.pending;
  if (action == null || !action.ready) return null;
  final question = action.kind.question;
  final evidence = action.evidence;
  if (evidence == null) return question;
  // A write measures from empty, so churn is always ~100% — words say it all.
  if (action.kind == PlanActionKind.write) return '$question ${evidence.wordsAfter} words on the page.';
  final pct = (evidence.churn * 100).round();
  final words = evidence.wordsBefore != evidence.wordsAfter ? ', ${evidence.wordsBefore} → ${evidence.wordsAfter} words' : '';
  return '$question $pct% changed since tagged$words.';
}
