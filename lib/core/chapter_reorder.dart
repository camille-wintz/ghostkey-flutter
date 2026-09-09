import '../server/dto/projects.dart';
import 'chapter_search.dart';

/// `list` with the item at `from` moved so that it ends up at `to`.
List<T> moveItem<T>(List<T> list, int from, int to) {
  final next = List<T>.from(list);
  final item = next.removeAt(from);
  next.insert(to, item);
  return next;
}

/// The chapter tree after the chapter drawn at row `from` is dropped at row
/// `to` — the rows being the tree as it is drawn (see `filterChapterTree`
/// with no query), folder headings included.
///
/// Where a dropped chapter lands decides which folder, if any, it belongs to:
/// it takes the nesting of the row it now sits under. Under an open folder's
/// heading it becomes that folder's first chapter; under one of a folder's
/// chapters it joins the folder; under a top-level chapter, or under a
/// collapsed folder, it sits at the top level. Collapsed folders travel as a
/// unit and keep their chapters. Only chapter rows move.
List<ChaptersListEntry> moveChapterRow(
  List<ChaptersListEntry> tree,
  List<ChapterListRow> rows,
  int from,
  int to,
  bool Function(String folder) isCollapsed,
) {
  final moved = from >= 0 && from < rows.length ? rows[from] : null;
  if (moved is! ChapterRow || from == to) return List.of(tree);

  final placed = moveItem(rows, from, to);
  final above = to > 0 ? placed[to - 1] : null;
  final nested = switch (above) {
    null => false,
    FolderRow() => !isCollapsed(above.name),
    ChapterRow() => above.nested,
  };
  placed[to] = moved.withNested(nested);

  return _rowsToTree(tree, placed, isCollapsed);
}

List<ChaptersListEntry> _rowsToTree(
  List<ChaptersListEntry> tree,
  List<ChapterListRow> rows,
  bool Function(String folder) isCollapsed,
) {
  final out = <ChaptersListEntry>[];
  List<DocumentSummary>? open;

  for (final row in rows) {
    switch (row) {
      case FolderRow():
        final collapsed = isCollapsed(row.name);
        final chapters = collapsed
            ? List<DocumentSummary>.of(_originalGroup(tree, row.name)?.chapters ?? const [])
            : <DocumentSummary>[];
        out.add(ChapterGroup(name: row.name, chapters: chapters));
        open = collapsed ? null : chapters;
      case ChapterRow():
        if (row.nested && open != null) {
          open.add(row.doc);
          continue;
        }
        out.add(row.doc);
        open = null;
    }
  }
  return out;
}

ChapterGroup? _originalGroup(List<ChaptersListEntry> tree, String name) {
  for (final entry in tree) {
    if (entry is ChapterGroup && entry.name == name) return entry;
  }
  return null;
}
