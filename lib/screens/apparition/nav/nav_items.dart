import 'dart:math';

import '../../../core/chapter_search.dart';
import '../../../ds/tokens.dart';
import '../../../server/dto/projects.dart';

// The panel's two sections flattened into one list of items, with the layout
// table the list positions itself by. Pure: `test/apparition/` pins it.
//
// The table is computed here rather than measured because the list has to
// know where a row it has never mounted sits: it is what lets a
// hundred-chapter book open on chapter ninety without drawing the eighty-nine
// above it. Every row's height comes from a token, so the arithmetic holds.

/// Rows above the active one that stay visible, so it opens with its
/// neighbours around it rather than pinned to the top edge.
const int leadRows = 3;

const double navGapHeight = 10;

/// A one-line notice (the body step's 22px line) with 10 of padding either
/// side of it.
const double navMessageHeight = 22 + 20;

enum NavSection { chapters, notes }

/// One row of the panel's single list. Chapters and notes are two
/// reorderable groups drawn in one list, so every row that can be dragged
/// carries `index` — its place in *its own group*, which is what a drop
/// handler is indexed by, and never its place in the list.
sealed class NavItem {
  const NavItem();
  String get id;
  double get height => DsGeom.row;
}

class HeaderItem extends NavItem {
  const HeaderItem({required this.label, required this.section, required this.addable});
  final String label;
  final NavSection section;
  final bool addable;
  @override
  String get id => 'h-${section.name}';
}

class FolderItem extends NavItem {
  const FolderItem({required this.name, required this.index});
  final String name;
  final int index;
  @override
  String get id => 'g-$name';
}

class ChapterItem extends NavItem {
  const ChapterItem({required this.doc, required this.nested, required this.index});
  final DocumentSummary doc;
  final bool nested;
  final int index;
  @override
  String get id => 'c-${doc.id}';
}

class NoteItem extends NavItem {
  const NoteItem({required this.doc, required this.index});
  final DocumentSummary doc;
  final int index;
  @override
  String get id => 'n-${doc.id}';
}

class GapItem extends NavItem {
  const GapItem();
  @override
  String get id => 'gap-notes';
  @override
  double get height => navGapHeight;
}

class MessageItem extends NavItem {
  const MessageItem(this.text);
  final String text;
  @override
  String get id => 'm-chapters';
  @override
  double get height => navMessageHeight;
}

/// The list as it is drawn, and where everything in it sits.
class NavLayout {
  const NavLayout({
    required this.items,
    required this.offsets,
    required this.chapterRows,
    required this.notes,
    required this.chaptersMessage,
    required this.showNotes,
  });

  final List<NavItem> items;

  /// Content offset of each item, by list index.
  final List<double> offsets;

  /// The chapter group's rows in draw order — what a chapter drop is
  /// indexed against.
  final List<ChapterListRow> chapterRows;

  /// The note group's rows in draw order.
  final List<DocumentSummary> notes;

  /// What the chapter section says instead of rows, when it has none.
  final String? chaptersMessage;

  /// A search that matches no note hides the section rather than heading an
  /// empty one.
  final bool showNotes;

  /// Where the active chapter's row sits, for the reveal on open. Only the
  /// chapter list is reachable this way; a note is one tap down a short
  /// list and never needs finding.
  double? offsetOfChapter(String? filename) {
    if (filename == null) return null;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is ChapterItem && item.doc.filename == filename) return offsets[i];
    }
    return null;
  }
}

/// The two sections flattened into one list, plus the offset table.
NavLayout layoutNav(List<ChapterListRow> rows, List<DocumentSummary> shownNotes, String query) {
  final items = <NavItem>[
    const HeaderItem(label: 'Chapters', section: NavSection.chapters, addable: true),
  ];

  final chaptersMessage = rows.isEmpty ? (query.isNotEmpty ? 'No chapter by that name.' : 'No chapters yet.') : null;
  if (chaptersMessage != null) items.add(MessageItem(chaptersMessage));
  for (var index = 0; index < rows.length; index++) {
    items.add(switch (rows[index]) {
      FolderRow(:final name) => FolderItem(name: name, index: index),
      ChapterRow(:final doc, :final nested) => ChapterItem(doc: doc, nested: nested, index: index),
    });
  }

  // A search reaches the notes too — hiding them would mean a note you can
  // see by name is one you cannot find by name.
  final showNotes = query.isEmpty || shownNotes.isNotEmpty;
  if (showNotes) {
    items.add(const GapItem());
    items.add(HeaderItem(label: 'Notes', section: NavSection.notes, addable: query.isEmpty));
    for (var index = 0; index < shownNotes.length; index++) {
      items.add(NoteItem(doc: shownNotes[index], index: index));
    }
  }

  final offsets = <double>[];
  var offset = 0.0;
  for (final item in items) {
    offsets.add(offset);
    offset += item.height;
  }

  return NavLayout(
    items: items,
    offsets: offsets,
    chapterRows: rows,
    notes: shownNotes,
    chaptersMessage: chaptersMessage,
    showNotes: showNotes,
  );
}

/// The scroll offset that opens the list on the active row with its
/// neighbours above it.
double revealOffset(double activeOffset) => max(0, activeOffset - leadRows * DsGeom.row);
