import '../../../server/dto/projects.dart';

// Pure edits to the chapter tree and the note list, for the panel's writes.

List<String> chapterFilenamesInTree(List<ChaptersListEntry> tree) =>
    chaptersInTree(tree).map((d) => d.filename).toList();

String nextChapterFilename(Iterable<String> existing) {
  final taken = existing.toSet();
  for (var n = 1;; n++) {
    final candidate = 'chapter-$n.md';
    if (!taken.contains(candidate)) return candidate;
  }
}

/// Matches the desktop's note naming ("Note N.md").
String nextNoteFilename(Iterable<String> existing) {
  final taken = existing.toSet();
  for (var n = 1;; n++) {
    final candidate = 'Note $n.md';
    if (!taken.contains(candidate)) return candidate;
  }
}

/// The tree with one document gone. A folder emptied by it stays: the
/// author made it, and a delete is not a request to lose it. The server
/// soft-deletes the document and leaves the tree to the client.
List<ChaptersListEntry> removeDocumentFromTree(List<ChaptersListEntry> tree, String documentId) => [
      for (final entry in tree)
        switch (entry) {
          DocumentSummary() => entry.id == documentId ? null : entry,
          ChapterGroup() => ChapterGroup(
              name: entry.name,
              chapters: entry.chapters.where((d) => d.id != documentId).toList(),
            ),
        },
    ].nonNulls.toList();
