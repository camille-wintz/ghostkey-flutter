import '../server/dto/plan.dart';
import '../server/dto/projects.dart';
import 'proposal.dart';

// A changeset is a diff against the written book — everything no op names
// stays exactly as it is — so it is read laid over the book: a remove under
// the last chapter it names, with each of them marked; an add where it will
// land, one row per chapter it writes; a rewrite standing where the first
// chapter it retells stood. Pure: a projection of (book, ops, what the author
// skipped).

/// One row of the book with the changes laid over it.
sealed class OverlayRow {
  const OverlayRow();
}

/// A part's heading — read, never edited here.
class OverlayPart extends OverlayRow {
  const OverlayPart(this.name);
  final String name;
}

/// A chapter the book has; [removedBy] when an op the author has not skipped
/// takes it out.
class OverlayChapter extends OverlayRow {
  const OverlayChapter(this.doc, {required this.number, this.removedBy});
  final DocumentSummary doc;
  final int number;
  final ChangesetRemove? removedBy;
}

/// A rewrite the author has not skipped, standing in the place of the first
/// chapter it retells.
class OverlayRewrite extends OverlayRow {
  const OverlayRewrite(this.op, {required this.replaces, required this.number});
  final ChangesetRewrite op;
  final DocumentSummary replaces;
  final int number;
}

/// One chapter an add the author has not skipped writes, where it will land.
/// [index] is into the op's written chapters.
class OverlayAdded extends OverlayRow {
  const OverlayAdded(this.op, this.index);
  final ChangesetAdd op;
  final int index;
}

/// An op as a card: every remove, and any op the author skipped. [orphan]
/// when it names no chapter this draft has.
class OverlayOp extends OverlayRow {
  const OverlayOp(this.op, {this.orphan = false});
  final ChangesetOp op;
  final bool orphan;
}

List<OverlayRow> overlayChangeset(List<ChaptersListEntry> tree, List<ChangesetOp> ops, bool Function(String opId) skipped) {
  final docs = chaptersInTree(tree);
  final order = {for (final (i, d) in docs.indexed) d.id: i};
  final atHead = <ChangesetOp>[];
  final after = <String, List<ChangesetOp>>{};
  final orphans = <ChangesetOp>[];
  final removedBy = <String, ChangesetRemove>{};
  // Chapter id → the rewrite standing in its place; null for the later
  // chapters of a merge, which fold into the first one's row.
  final replaced = <String, ChangesetRewrite?>{};
  void place(String anchor, ChangesetOp op) => (after[anchor] ??= []).add(op);

  for (final op in ops) {
    if (op is ChangesetAdd) {
      final anchor = op.after;
      if (anchor == null) {
        atHead.add(op);
      } else if (order.containsKey(anchor.documentId)) {
        place(anchor.documentId, op);
      } else {
        orphans.add(op);
      }
      continue;
    }
    final refs = switch (op) {
      ChangesetRemove(:final chapters) => chapters,
      ChangesetRewrite(:final chapters) => chapters,
      ChangesetAdd() => const <ChangesetChapterRef>[],
    };
    final named = refs.where((c) => order.containsKey(c.documentId)).toList()
      ..sort((a, b) => order[a.documentId]!.compareTo(order[b.documentId]!));
    if (named.isEmpty) {
      orphans.add(op);
      continue;
    }
    if (op is ChangesetRewrite && !skipped(op.id)) {
      replaced[named.first.documentId] = op;
      for (final c in named.skip(1)) {
        replaced[c.documentId] = null;
      }
      continue;
    }
    if (op is ChangesetRemove && !skipped(op.id)) {
      for (final c in named) {
        removedBy[c.documentId] = op;
      }
    }
    place(named.last.documentId, op);
  }

  final out = <OverlayRow>[];
  void emit(ChangesetOp op) {
    if (op is ChangesetAdd && !skipped(op.id)) {
      for (var i = 0; i < op.written.length; i++) {
        out.add(OverlayAdded(op, i));
      }
    } else {
      out.add(OverlayOp(op));
    }
  }

  atHead.forEach(emit);
  void chapter(DocumentSummary doc) {
    final number = order[doc.id]! + 1;
    if (replaced.containsKey(doc.id)) {
      final rewrite = replaced[doc.id];
      if (rewrite != null) out.add(OverlayRewrite(rewrite, replaces: doc, number: number));
    } else {
      out.add(OverlayChapter(doc, number: number, removedBy: removedBy[doc.id]));
    }
    after[doc.id]?.forEach(emit);
  }

  for (final entry in tree) {
    switch (entry) {
      case DocumentSummary():
        chapter(entry);
      case ChapterGroup():
        out.add(OverlayPart(entry.name));
        entry.chapters.forEach(chapter);
    }
  }
  for (final op in orphans) {
    out.add(OverlayOp(op, orphan: true));
  }
  return out;
}

/// The chapters an applied changeset hands over with text they could start
/// from, counted the way the server projects them: every chapter no approved
/// op names is kept (and carries its words by default), and a rewrite's
/// cards reference old chapters (and start blank by default).
({int kept, int rewritten}) changesetCarryCounts(List<ChaptersListEntry> tree, List<ChangesetOp> approved) {
  final named = <String>{};
  var rewritten = 0;
  for (final op in approved) {
    switch (op) {
      case ChangesetAdd():
        continue;
      case ChangesetRemove(:final chapters):
        named.addAll(chapters.map((c) => c.documentId));
      case ChangesetRewrite(:final chapters, :final written):
        named.addAll(chapters.map((c) => c.documentId));
        // The first card falls back to the first old chapter; the rest
        // reference only the chapter they name.
        rewritten += [for (final (i, w) in written.indexed) if (i == 0 || w.from != null) w].length;
    }
  }
  final kept = chaptersInTree(tree).where((d) => !named.contains(d.id)).length;
  return (kept: kept, rewritten: rewritten);
}

/// The footer's carry question for a changeset. [choice] null is the
/// changeset's own answer: kept chapters keep their words, rewritten ones
/// start blank.
CarryState changesetCarry(({int kept, int rewritten}) counts, bool? choice) {
  final carryable = counts.kept + counts.rewritten;
  final carried = switch (choice) {
    null => counts.kept,
    true => carryable,
    false => 0,
  };
  return carryState(carried, carryable, mixedSuffix: ' — rewritten ones start blank');
}

String _compact(int n) => n >= 10000 ? '${(n / 1000).round()}k' : n.toString();

/// The ledger as the one line a diff shows above itself: chapters and words
/// before → after, the size of the change, and who leaves the book.
String ledgerLine(ChangesetLedger ledger) {
  final parts = ['${ledger.chaptersBefore} → ${ledger.chaptersAfter} chapters'];
  if (ledger.wordsBefore > 0) {
    final delta = ((ledger.wordsAfter - ledger.wordsBefore) / ledger.wordsBefore * 100).round();
    final sign = delta > 0 ? '+' : '';
    parts.add(
      '${_compact(ledger.wordsBefore)} → ~${_compact(ledger.wordsAfter)} words${delta != 0 ? ' ($sign$delta%)' : ''}',
    );
  }
  final change = [
    if (ledger.removedChapters > 0) '${ledger.removedChapters} removed',
    if (ledger.rewrittenChapters > 0) '${ledger.rewrittenChapters} rewritten',
    if (ledger.writtenChapters > 0) '${ledger.writtenChapters} written',
  ];
  if (change.isNotEmpty) parts.add(change.join(', '));
  final leaving = ledger.charactersLeaving;
  if (leaving.isNotEmpty) {
    parts.add('${leaving.length} ${leaving.length == 1 ? 'character leaves' : 'characters leave'} the book: ${leaving.join(', ')}');
  }
  return parts.join(' · ');
}
