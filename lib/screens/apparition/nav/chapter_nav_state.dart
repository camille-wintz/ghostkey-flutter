import 'package:flutter/foundation.dart';

import '../../../core/chapter_reorder.dart';
import '../../../core/chapter_search.dart';
import '../../../server/dto/projects.dart';
import '../../../server/projects/api.dart';
import 'tree_edits.dart';

/// What the list remembers between opens, and every write it makes.
///
/// Lives above the panel, in the room: the panel is a route that is gone the
/// moment it closes, so the query, the folded folders and an order that has
/// not landed yet would all go with it. Owned once so the two rows
/// that can lift (chapters, notes) and the writes that follow a drop have
/// one place to agree on what is pending.
///
/// Reorders are optimistic without a cache to patch: the moved order is held
/// here and drawn in place of the server's until the server's own read has
/// caught up — a draft version at or past the one the write landed on, or a
/// note order that matches. A refused write drops the held order and
/// refetches, which puts the list back the way the server has it.
class ChapterNavState extends ChangeNotifier {
  ChapterNavState({required this.projectId, required this.refreshProject});

  final String projectId;

  /// Drop the project read so it refetches. The list never reads stale.
  final void Function() refreshProject;

  String _query = '';
  final Set<String> _collapsed = {};
  List<ChaptersListEntry>? _optimisticChapters;
  int _landedDraftVersion = 0;
  List<DocumentSummary>? _optimisticNotes;
  bool _pending = false;

  String get query => _query;

  /// A write is in flight. A second lift meanwhile would be made against a
  /// draft version the first write is about to move, and be refused.
  bool get pending => _pending;

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  /// Folders are expanded by default; tapping the row collapses them.
  bool isCollapsed(String folder) => _collapsed.contains(folder);

  void toggleFolder(String folder) {
    if (!_collapsed.remove(folder)) _collapsed.add(folder);
    notifyListeners();
  }

  /// The chapter tree to draw: the held order until the server has it.
  List<ChaptersListEntry> chaptersOf(ProjectFull data) {
    final held = _optimisticChapters;
    if (held == null) return data.chapters;
    if (data.draft.version >= _landedDraftVersion) {
      _optimisticChapters = null;
      return data.chapters;
    }
    return held;
  }

  /// The draft version a reorder is made against — the landed one while the
  /// held order stands, or a quick second drag would be refused as stale.
  int draftVersionOf(ProjectFull data) =>
      _optimisticChapters != null && data.draft.version < _landedDraftVersion ? _landedDraftVersion : data.draft.version;

  List<DocumentSummary> notesOf(ProjectFull data) {
    final held = _optimisticNotes;
    if (held == null) return data.notes;
    if (_sameOrder(held, data.notes)) {
      _optimisticNotes = null;
      return data.notes;
    }
    return held;
  }

  static bool _sameOrder(List<DocumentSummary> a, List<DocumentSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// A chapter row dropped at a new slot rewrites the active draft's tree,
  /// against the tree as it is drawn. Throws the server's refusal.
  Future<void> moveChapter(ProjectFull data, List<ChapterListRow> rows, int from, int to) async {
    if (from == to) return;
    final chapters = moveChapterRow(chaptersOf(data), rows, from, to, isCollapsed);
    _optimisticChapters = chapters;
    _pending = true;
    notifyListeners();
    try {
      final draft = await patchDraftChapters(
        projectId,
        data.project.activeDraftId,
        chapters,
        baseVersion: draftVersionOf(data),
      );
      _landedDraftVersion = draft.version;
    } catch (_) {
      _optimisticChapters = null;
      rethrow;
    } finally {
      _pending = false;
      refreshProject();
      notifyListeners();
    }
  }

  /// A note row dropped at a new slot rewrites the project's note order.
  Future<void> moveNote(ProjectFull data, int from, int to) async {
    if (from == to) return;
    final notes = moveItem(notesOf(data), from, to);
    _optimisticNotes = notes;
    _pending = true;
    notifyListeners();
    try {
      await patchProject(projectId, notes: notes);
    } catch (_) {
      _optimisticNotes = null;
      rethrow;
    } finally {
      _pending = false;
      refreshProject();
      notifyListeners();
    }
  }

  /// Chapter ordering lives on the active draft, not the project: append the
  /// freshly created document to the existing order and persist it via the
  /// drafts PATCH. Returns the new chapter's filename.
  Future<String> createChapter(ProjectFull data) async {
    final chapters = chaptersOf(data);
    final filename = nextChapterFilename(chapterFilenamesInTree(chapters));
    final document = await createDocument(projectId, kind: DocumentKind.chapter, filename: filename);
    await patchDraftChapters(projectId, data.project.activeDraftId, [...chapters, document.summary]);
    refreshProject();
    return filename;
  }

  /// Same shape as chapters: append to the existing note order and persist
  /// it; the server rebuilds its internal note_order from this.
  Future<String> createNote(ProjectFull data) async {
    final notes = notesOf(data);
    final filename = nextNoteFilename(notes.map((n) => n.filename));
    final document = await createDocument(projectId, kind: DocumentKind.note, filename: filename);
    await patchProject(projectId, notes: [...notes, document.summary]);
    refreshProject();
    return filename;
  }

  /// Returns the filename the document now has.
  Future<String> rename(DocumentSummary doc, String title) async {
    final renamed = await renameDocument(projectId, doc.id, '$title.md');
    refreshProject();
    return renamed.filename;
  }

  /// The server soft-deletes and leaves the tree to the client.
  Future<void> deleteChapter(ProjectFull data, DocumentSummary doc) async {
    await deleteDocument(projectId, doc.id);
    await patchDraftChapters(
      projectId,
      data.project.activeDraftId,
      removeDocumentFromTree(chaptersOf(data), doc.id),
      baseVersion: draftVersionOf(data),
    );
    _optimisticChapters = null;
    refreshProject();
  }

  Future<void> deleteNote(ProjectFull data, DocumentSummary doc) async {
    await deleteDocument(projectId, doc.id);
    await patchProject(projectId, notes: notesOf(data).where((n) => n.id != doc.id).toList());
    _optimisticNotes = null;
    refreshProject();
  }
}
