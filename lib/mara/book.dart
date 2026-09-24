import '../server/dto/projects.dart';

// The book as the Chapters page lists it once nothing is proposed: the
// manuscript's own chapters, in order, under their parts, each with the plan
// row that carries what it is for. Titles, order and parts are Apparition's;
// the row is Poltergeist's plan board's.

sealed class BookRow {
  const BookRow();
}

class BookPartRow extends BookRow {
  const BookPartRow(this.name);
  final String name;
}

class BookChapterRow extends BookRow {
  const BookChapterRow(this.doc, {required this.number, required this.row});
  final DocumentSummary doc;
  final int number;

  /// The plan row carrying its notes and target; null until the board's
  /// reconcile has minted one.
  final PlanChapter? row;
}

List<BookRow> bookRows(List<ChaptersListEntry> tree, ProjectPlan? plan) {
  final rows = <String, PlanChapter>{};
  for (final r in plan?.chapters ?? const <PlanChapter>[]) {
    if (r.documentId case final id?) rows[id] = r;
  }
  var number = 0;
  BookChapterRow chapter(DocumentSummary doc) => BookChapterRow(doc, number: ++number, row: rows[doc.id]);
  return [
    for (final entry in tree)
      ...switch (entry) {
        DocumentSummary() => [chapter(entry)],
        ChapterGroup() => [BookPartRow(entry.name), ...entry.chapters.map(chapter)],
      },
  ];
}
