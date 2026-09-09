import '../server/dto/projects.dart';

/// What the board renders, top to bottom: a loose row, or a folder with the
/// rows of the chapters inside it.
sealed class PlanTreeEntry {
  const PlanTreeEntry();
}

class PlanRowEntry extends PlanTreeEntry {
  const PlanRowEntry(this.row);
  final PlanChapter row;
}

class PlanFolderEntry extends PlanTreeEntry {
  const PlanFolderEntry({required this.name, required this.rows});
  final String name;
  final List<PlanChapter> rows;
}

/// Project the plan's flat rows onto the manuscript's chapter tree — the tree
/// owns the structure, the plan owns each row's worklist state. Rows whose
/// chapter is gone (`missing`) have no place in the tree, so they trail the
/// row they followed in the plan, at the top level. Chapters with no row yet
/// stay hidden until the next reconcile mints one.
List<PlanTreeEntry> planTree(List<PlanChapter> rows, List<ChaptersListEntry> chapters) {
  final rowByDocId = <String, PlanChapter>{};
  for (final row in rows) {
    final documentId = row.documentId;
    if (documentId != null) rowByDocId.putIfAbsent(documentId, () => row);
  }

  // Orphans, grouped by the last linked row ahead of them in plan order.
  final orphansAfter = <String?, List<PlanChapter>>{};
  String? lastLinked;
  for (final row in rows) {
    final documentId = row.documentId;
    if (documentId != null && identical(rowByDocId[documentId], row)) {
      lastLinked = row.id;
      continue;
    }
    orphansAfter.putIfAbsent(lastLinked, () => []).add(row);
  }

  final placed = <String>{};
  final entries = <PlanTreeEntry>[];
  void pushRow(PlanChapter row) {
    entries.add(PlanRowEntry(row));
    placed.add(row.id);
  }

  void pushOrphansAfter(String? rowId) {
    for (final orphan in orphansAfter[rowId] ?? const <PlanChapter>[]) {
      pushRow(orphan);
    }
  }

  pushOrphansAfter(null);
  for (final entry in chapters) {
    switch (entry) {
      case DocumentSummary():
        final row = rowByDocId[entry.id];
        if (row == null) continue;
        pushRow(row);
        pushOrphansAfter(row.id);
      case ChapterGroup():
        final folderRows = [for (final c in entry.chapters) ?rowByDocId[c.id]];
        entries.add(PlanFolderEntry(name: entry.name, rows: folderRows));
        for (final row in folderRows) {
          placed.add(row.id);
          pushOrphansAfter(row.id);
        }
    }
  }
  // Anything that followed a row the manuscript no longer has: keep it, last.
  for (final row in rows) {
    if (!placed.contains(row.id)) pushRow(row);
  }
  return entries;
}

/// The board as one flat, virtualizable list: a folder header followed by
/// its rows, loose rows bare. `open` says which folders show their rows.
sealed class PlanListItem {
  const PlanListItem();
}

class PlanFolderHeaderItem extends PlanListItem {
  const PlanFolderHeaderItem({required this.name, required this.rows, required this.open});
  final String name;
  final List<PlanChapter> rows;
  final bool open;
}

class PlanRowItem extends PlanListItem {
  const PlanRowItem(this.row, {required this.inFolder, required this.last});
  final PlanChapter row;
  final bool inFolder;

  /// The last row of its group — the one without a hairline under it.
  final bool last;
}

List<PlanListItem> planListItems(List<PlanTreeEntry> entries, bool Function(String folder) isOpen) {
  final items = <PlanListItem>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    switch (entry) {
      case PlanRowEntry():
        final next = i + 1 < entries.length ? entries[i + 1] : null;
        items.add(PlanRowItem(entry.row, inFolder: false, last: next is! PlanRowEntry));
      case PlanFolderEntry():
        final open = isOpen(entry.name);
        items.add(PlanFolderHeaderItem(name: entry.name, rows: entry.rows, open: open));
        if (!open) continue;
        for (var j = 0; j < entry.rows.length; j++) {
          items.add(PlanRowItem(entry.rows[j], inFolder: true, last: j == entry.rows.length - 1));
        }
    }
  }
  return items;
}
