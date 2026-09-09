import '../../server/dto/projects.dart';

/// A rename the room made that the project read has not caught up with.
///
/// The active chapter is held by FILENAME, and a rename changes the filename
/// before the refetched tree can name the document by it. Without this the
/// editor would resolve the new name to nothing for a frame, drop the open
/// document and reload it — flushing and re-fetching a chapter the author is
/// still typing in. Both the title block and the drawer note their rename
/// here; the resolver falls back to it for exactly that gap.
class RecentRename {
  String? _documentId;
  String? _filename;

  void note(String documentId, String filename) {
    _documentId = documentId;
    _filename = filename;
  }

  String? idFor(String filename) => filename == _filename ? _documentId : null;
}

/// The document a filename names, in the chapter tree or the notes.
String? resolveDocumentId(ProjectFull data, String filename, [RecentRename? recent]) {
  for (final entry in data.chapters) {
    switch (entry) {
      case DocumentSummary():
        if (entry.filename == filename) return entry.id;
      case ChapterGroup():
        for (final doc in entry.chapters) {
          if (doc.filename == filename) return doc.id;
        }
    }
  }
  for (final note in data.notes) {
    if (note.filename == filename) return note.id;
  }
  return recent?.idFor(filename);
}
