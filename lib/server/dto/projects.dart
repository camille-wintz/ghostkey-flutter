import 'json.dart';

class Folder {
  const Folder({
    required this.id,
    required this.ownerId,
    required this.parentId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String? parentId;
  final String name;
  final String createdAt;
  final String updatedAt;

  static Folder fromJson(Json json) => Folder(
        id: asString(json['id']),
        ownerId: asString(json['owner_id']),
        parentId: json['parent_id'] as String?,
        name: asString(json['name']),
        createdAt: asString(json['created_at']),
        updatedAt: asString(json['updated_at']),
      );
}

enum DocumentKind {
  chapter,
  note;

  static DocumentKind fromWire(String value) =>
      value == 'note' ? DocumentKind.note : DocumentKind.chapter;
}

class SavedPrompt {
  const SavedPrompt({required this.id, required this.name, required this.prompt, this.taskListJson});
  final String id;
  final String name;
  final String prompt;
  final String? taskListJson;

  static SavedPrompt fromJson(Json json) => SavedPrompt(
        id: asString(json['id']),
        name: asString(json['name']),
        prompt: asString(json['prompt']),
        taskListJson: json['task_list_json'] as String?,
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        if (taskListJson != null) 'task_list_json': taskListJson,
      };
}

class CoverThumbnail {
  const CoverThumbnail({
    required this.status,
    required this.url,
    required this.etag,
    required this.updatedAt,
  });

  /// `available`: a cover asset exists; the thumbnail is generated on first
  /// GET. `ready`: a cached thumbnail is available. The `url` works in both.
  final String status;
  final String url;
  final String? etag;
  final String? updatedAt;

  static CoverThumbnail fromJson(Json json) => CoverThumbnail(
        status: asString(json['status']),
        url: asString(json['url']),
        etag: json['etag'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}

/// The quote style a project's smart typography runs in — a project setting.
enum TypographyMode {
  curly,
  guillemets,
  german,
  none;

  static TypographyMode fromWire(String? value) => switch (value) {
        'guillemets' => TypographyMode.guillemets,
        'german' => TypographyMode.german,
        'none' => TypographyMode.none,
        _ => TypographyMode.curly,
      };
}

class ProjectMeta {
  const ProjectMeta({
    required this.id,
    required this.ownerId,
    required this.folderId,
    required this.seriesId,
    required this.seriesIndex,
    required this.name,
    required this.title,
    required this.description,
    required this.author,
    required this.coverFilename,
    required this.coverThumbnail,
    required this.coverBackdrop,
    required this.savedPrompts,
    required this.typography,
    required this.activeDraftId,
    required this.activeDraftVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String? folderId;
  final String seriesId;
  final int seriesIndex;
  final String name;
  final String title;
  final String description;
  final String author;
  final String coverFilename;
  final CoverThumbnail? coverThumbnail;

  /// The same cover, small and already blurred, for the project home's stage.
  /// Same shape and same lifecycle as [coverThumbnail].
  final CoverThumbnail? coverBackdrop;
  final List<SavedPrompt> savedPrompts;
  final TypographyMode typography;

  /// The draft currently being written in — the only writable manuscript.
  final String activeDraftId;
  final int activeDraftVersion;
  final String createdAt;
  final String updatedAt;

  String get displayTitle => title.isNotEmpty ? title : name;

  static ProjectMeta fromJson(Json json) => ProjectMeta(
        id: asString(json['id']),
        ownerId: asString(json['owner_id']),
        folderId: json['folder_id'] as String?,
        seriesId: asString(json['series_id']),
        seriesIndex: asInt(json['series_index']),
        name: asString(json['name']),
        title: asString(json['title']),
        description: asString(json['description']),
        author: asString(json['author']),
        coverFilename: asString(json['cover_filename']),
        coverThumbnail: json['cover_thumbnail'] == null
            ? null
            : CoverThumbnail.fromJson(asJson(json['cover_thumbnail'])),
        coverBackdrop: json['cover_backdrop'] == null
            ? null
            : CoverThumbnail.fromJson(asJson(json['cover_backdrop'])),
        savedPrompts: asJsonList(json['saved_prompts']).map(SavedPrompt.fromJson).toList(),
        typography: TypographyMode.fromWire(json['typography'] as String?),
        activeDraftId: asString(json['active_draft_id']),
        activeDraftVersion: asInt(json['active_draft_version']),
        createdAt: asString(json['created_at']),
        updatedAt: asString(json['updated_at']),
      );

  ProjectMeta copyWith({int? activeDraftVersion}) => ProjectMeta(
        id: id,
        ownerId: ownerId,
        folderId: folderId,
        seriesId: seriesId,
        seriesIndex: seriesIndex,
        name: name,
        title: title,
        description: description,
        author: author,
        coverFilename: coverFilename,
        coverThumbnail: coverThumbnail,
        coverBackdrop: coverBackdrop,
        savedPrompts: savedPrompts,
        typography: typography,
        activeDraftId: activeDraftId,
        activeDraftVersion: activeDraftVersion ?? this.activeDraftVersion,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// One entry of the composed `chapters` list GET /api/projects/:id returns:
/// a chapter document, or a one-level folder grouping chapter documents.
/// Order is implicit in the array.
sealed class ChaptersListEntry {
  Json toJson();
}

class DocumentSummary implements ChaptersListEntry {
  const DocumentSummary({
    required this.id,
    required this.kind,
    required this.filename,
    required this.version,
    required this.wordCount,
    required this.updatedAt,
  });

  final String id;
  final DocumentKind kind;
  final String filename;
  final int version;

  /// Words in the content, maintained server-side. Null on a locally built
  /// summary that has no count yet.
  final int? wordCount;
  final String updatedAt;

  /// The visible title: the filename minus `.md`.
  String get label => filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');

  static DocumentSummary fromJson(Json json) => DocumentSummary(
        id: asString(json['id']),
        kind: DocumentKind.fromWire(asString(json['kind'])),
        filename: asString(json['filename']),
        version: asInt(json['version']),
        wordCount: json['word_count'] as int?,
        updatedAt: asString(json['updated_at']),
      );

  DocumentSummary copyWith({String? filename}) => DocumentSummary(
        id: id,
        kind: kind,
        filename: filename ?? this.filename,
        version: version,
        wordCount: wordCount,
        updatedAt: updatedAt,
      );

  @override
  Json toJson() => {
        'id': id,
        'kind': kind.name,
        'filename': filename,
        'version': version,
        if (wordCount != null) 'word_count': wordCount,
        'updated_at': updatedAt,
      };
}

class ChapterGroup implements ChaptersListEntry {
  const ChapterGroup({required this.name, required this.chapters});
  final String name;
  final List<DocumentSummary> chapters;

  static ChapterGroup fromJson(Json json) => ChapterGroup(
        name: asString(json['name']),
        chapters: asJsonList(json['chapters']).map(DocumentSummary.fromJson).toList(),
      );

  @override
  Json toJson() => {
        'name': name,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };
}

ChaptersListEntry chaptersListEntryFromJson(Json json) =>
    json['name'] is String && json['chapters'] is List
        ? ChapterGroup.fromJson(json)
        : DocumentSummary.fromJson(json);

/// Every chapter document in a tree, folders flattened, in reading order.
List<DocumentSummary> chaptersInTree(List<ChaptersListEntry> tree) {
  final out = <DocumentSummary>[];
  for (final entry in tree) {
    switch (entry) {
      case DocumentSummary():
        out.add(entry);
      case ChapterGroup():
        out.addAll(entry.chapters);
    }
  }
  return out;
}

class DocumentDto {
  const DocumentDto({
    required this.summary,
    required this.projectId,
    required this.content,
    required this.createdAt,
  });

  final DocumentSummary summary;
  final String projectId;
  final String content;
  final String createdAt;

  String get id => summary.id;
  String get filename => summary.filename;
  int get version => summary.version;

  static DocumentDto fromJson(Json json) => DocumentDto(
        summary: DocumentSummary.fromJson(json),
        projectId: asString(json['project_id']),
        content: asString(json['content']),
        createdAt: asString(json['created_at']),
      );
}

class AssetMeta {
  const AssetMeta({
    required this.id,
    required this.projectId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
  });

  final String id;
  final String projectId;
  final String filename;
  final String contentType;
  final int sizeBytes;

  static AssetMeta fromJson(Json json) => AssetMeta(
        id: asString(json['id']),
        projectId: asString(json['project_id']),
        filename: asString(json['filename']),
        contentType: asString(json['content_type']),
        sizeBytes: asInt(json['size_bytes']),
      );
}

class DraftSummary {
  const DraftSummary({required this.id, required this.name, required this.version, this.updatedAt});
  final String id;
  final String name;
  final int version;
  final String? updatedAt;

  static DraftSummary fromJson(Json json) => DraftSummary(
        id: asString(json['id']),
        name: asString(json['name']),
        version: asInt(json['version']),
        updatedAt: json['updated_at'] as String?,
      );
}

class ProjectFull {
  const ProjectFull({
    required this.project,
    required this.draft,
    required this.chapters,
    required this.notes,
    required this.assets,
  });

  final ProjectMeta project;

  /// The active draft, whose chapters `chapters` lists.
  final DraftSummary draft;
  final List<ChaptersListEntry> chapters;
  final List<DocumentSummary> notes;
  final List<AssetMeta> assets;

  static ProjectFull fromJson(Json json) => ProjectFull(
        project: ProjectMeta.fromJson(asJson(json['project'])),
        draft: DraftSummary.fromJson(asJson(json['draft'])),
        chapters: asJsonList(json['chapters']).map(chaptersListEntryFromJson).toList(),
        notes: asJsonList(json['notes']).map(DocumentSummary.fromJson).toList(),
        assets: asJsonList(json['assets']).map(AssetMeta.fromJson).toList(),
      );

  ProjectFull copyWith({
    ProjectMeta? project,
    DraftSummary? draft,
    List<ChaptersListEntry>? chapters,
    List<DocumentSummary>? notes,
  }) =>
      ProjectFull(
        project: project ?? this.project,
        draft: draft ?? this.draft,
        chapters: chapters ?? this.chapters,
        notes: notes ?? this.notes,
        assets: assets,
      );

  /// The project with one document renamed wherever it appears.
  ProjectFull withRenamedDocument(String documentId, String filename) {
    DocumentSummary rename(DocumentSummary d) =>
        d.id == documentId ? d.copyWith(filename: filename) : d;
    return copyWith(
      chapters: [
        for (final entry in chapters)
          switch (entry) {
            DocumentSummary() => rename(entry),
            ChapterGroup() => ChapterGroup(
                name: entry.name,
                chapters: entry.chapters.map(rename).toList(),
              ),
          },
      ],
      notes: notes.map(rename).toList(),
    );
  }
}

/// GET /api/series. Every project belongs to exactly one; an `implicit`
/// series is one the author never named, drawn as a bare book.
class Series {
  const Series({
    required this.id,
    required this.name,
    required this.implicit,
    required this.sortIndex,
    required this.bookCount,
  });

  final String id;
  final String name;
  final bool implicit;
  final int sortIndex;
  final int bookCount;

  static Series fromJson(Json json) => Series(
        id: asString(json['id']),
        name: asString(json['name']),
        implicit: asBool(json['implicit']),
        sortIndex: asInt(json['sort_index']),
        bookCount: asInt(json['book_count']),
      );
}

// ── Poltergeist's plan ───────────────────────────────────────────────────
// Client-owned JSON server-side: the server validates `format_version` and
// each chapter's `id`/`title` and passes everything else through. The full
// shape is the desktop's `shared/types/planActions.ts` + `plan.ts`; every
// class here keeps `raw` so a write echoes fields this client never reads.

/// The plan shape this build writes. A stored plan with a higher version was
/// written by a newer app and is left untouched rather than clobbered.
const int planFormatVersion = 2;

enum PlanActionKind {
  write,
  rewrite,
  lineEdit,
  move,
  delete;

  static PlanActionKind? fromWire(String? value) => switch (value) {
        'write' => PlanActionKind.write,
        'rewrite' => PlanActionKind.rewrite,
        'line_edit' => PlanActionKind.lineEdit,
        'move' => PlanActionKind.move,
        'delete' => PlanActionKind.delete,
        _ => null,
      };

  String get wire => switch (this) {
        PlanActionKind.write => 'write',
        PlanActionKind.rewrite => 'rewrite',
        PlanActionKind.lineEdit => 'line_edit',
        PlanActionKind.move => 'move',
        PlanActionKind.delete => 'delete',
      };

  /// Pending pill and menu entry.
  String get label => switch (this) {
        PlanActionKind.write => 'To write',
        PlanActionKind.rewrite => 'To rewrite',
        PlanActionKind.lineEdit => 'To line edit',
        PlanActionKind.move => 'To move',
        PlanActionKind.delete => 'To delete',
      };

  /// Past tense, shown on a clean row as its last completed action.
  String get doneLabel => switch (this) {
        PlanActionKind.write => 'Written',
        PlanActionKind.rewrite => 'Rewritten',
        PlanActionKind.lineEdit => 'Line edited',
        PlanActionKind.move => 'Moved',
        PlanActionKind.delete => 'Deleted',
      };

  /// One lowercase word, for counted tallies ("3 rewrite · 2 line").
  String get short => switch (this) {
        PlanActionKind.write => 'write',
        PlanActionKind.rewrite => 'rewrite',
        PlanActionKind.lineEdit => 'line',
        PlanActionKind.move => 'move',
        PlanActionKind.delete => 'delete',
      };

  /// Asked once the reconciler thinks it happened — textual kinds only.
  String get question => switch (this) {
        PlanActionKind.write => 'Written?',
        PlanActionKind.rewrite => 'Rewritten?',
        PlanActionKind.lineEdit => 'Line edited?',
        PlanActionKind.move => 'Moved?',
        PlanActionKind.delete => 'Deleted?',
      };

  /// Completion is measured against a content anchor and confirmed by the
  /// author; move and delete complete on a structural fact alone.
  bool get textual => switch (this) {
        PlanActionKind.write || PlanActionKind.rewrite || PlanActionKind.lineEdit => true,
        PlanActionKind.move || PlanActionKind.delete => false,
      };

  /// What confirming it leaves the chapter owing. Null ends the chain.
  PlanActionKind? get chainsTo => switch (this) {
        PlanActionKind.write || PlanActionKind.rewrite => PlanActionKind.lineEdit,
        _ => null,
      };
}

/// Menu order — drafting first, destructive last.
const List<PlanActionKind> planActionKinds = PlanActionKind.values;

/// The document's state when the action was assigned — what completion is
/// measured against. `fingerprint` is the desktop's minhash; this client
/// never computes one and writes null, which the desktop reads as "measure
/// from nothing".
class PlanActionAnchor {
  const PlanActionAnchor({this.version, this.words, this.fingerprint, this.prevDocumentId});
  final int? version;
  final int? words;
  final String? fingerprint;

  /// The linked document just before this one at assign time; null = first.
  final String? prevDocumentId;

  static const empty = PlanActionAnchor();

  static PlanActionAnchor fromJson(Json json) => PlanActionAnchor(
        version: json['version'] is num ? (json['version'] as num).toInt() : null,
        words: json['words'] is num ? (json['words'] as num).toInt() : null,
        fingerprint: json['fingerprint'] as String?,
        prevDocumentId: json['prev_document_id'] as String?,
      );

  Json toJson() => {
        'version': version,
        'words': words,
        'fingerprint': fingerprint,
        'prev_document_id': prevDocumentId,
      };
}

/// What the reconciler measured last time it looked.
class PlanActionEvidence {
  const PlanActionEvidence({required this.churn, required this.wordsBefore, required this.wordsAfter});

  /// 0..1 — estimated share of the text that changed since the anchor.
  final double churn;
  final int wordsBefore;
  final int wordsAfter;

  static PlanActionEvidence fromJson(Json json) => PlanActionEvidence(
        churn: asDouble(json['churn']),
        wordsBefore: asInt(json['words_before']),
        wordsAfter: asInt(json['words_after']),
      );

  Json toJson() => {'churn': churn, 'words_before': wordsBefore, 'words_after': wordsAfter};
}

/// A pending action on a row, whole: the kind, when it was assigned, what it
/// measures against, and whether the reconciler thinks it already happened.
class PlanAction {
  const PlanAction({
    required this.kind,
    required this.assignedAt,
    required this.anchor,
    required this.ready,
    required this.evidence,
    required this.raw,
  });

  final PlanActionKind kind;
  final String assignedAt;
  final PlanActionAnchor anchor;

  /// Textual kinds: looks done, awaiting the author's confirm.
  final bool ready;
  final PlanActionEvidence? evidence;
  final Json raw;

  /// A freshly assigned action, unmeasured.
  factory PlanAction.fresh(PlanActionKind kind, String assignedAt, {PlanActionAnchor anchor = PlanActionAnchor.empty}) =>
      PlanAction(
        kind: kind,
        assignedAt: assignedAt,
        anchor: anchor,
        ready: false,
        evidence: null,
        raw: {
          'kind': kind.wire,
          'assigned_at': assignedAt,
          'anchor': anchor.toJson(),
          'ready': false,
          'evidence': null,
        },
      );

  /// Null for a kind this build doesn't know — the row then reads as owing
  /// nothing rather than something wrong, and the write echoes it untouched.
  static PlanAction? fromJson(Json json) {
    final kind = PlanActionKind.fromWire(json['kind'] as String?);
    if (kind == null) return null;
    return PlanAction(
      kind: kind,
      assignedAt: asString(json['assigned_at']),
      anchor: json['anchor'] is Map ? PlanActionAnchor.fromJson(asJson(json['anchor'])) : PlanActionAnchor.empty,
      ready: asBool(json['ready']),
      evidence: json['evidence'] is Map ? PlanActionEvidence.fromJson(asJson(json['evidence'])) : null,
      raw: json,
    );
  }

  PlanAction copyWith({PlanActionAnchor? anchor, bool? ready, PlanActionEvidence? evidence, bool clearEvidence = false}) {
    final next = Map<String, dynamic>.from(raw);
    if (anchor != null) next['anchor'] = anchor.toJson();
    if (ready != null) next['ready'] = ready;
    if (clearEvidence) {
      next['evidence'] = null;
    } else if (evidence != null) {
      next['evidence'] = evidence.toJson();
    }
    return PlanAction.fromJson(next)!;
  }

  Json toJson() => raw;
}

class PlanHistoryEntry {
  const PlanHistoryEntry({required this.kind, required this.completedAt});
  final PlanActionKind kind;
  final String completedAt;

  static PlanHistoryEntry? fromJson(Json json) {
    final kind = PlanActionKind.fromWire(json['kind'] as String?);
    return kind == null ? null : PlanHistoryEntry(kind: kind, completedAt: asString(json['completed_at']));
  }

  Json toJson() => {'kind': kind.wire, 'completed_at': completedAt};
}

class PlanChapter {
  const PlanChapter({
    required this.id,
    required this.title,
    required this.documentId,
    required this.action,
    required this.done,
    required this.raw,
    this.filename,
    this.notes = '',
    this.pending,
    this.history = const [],
    this.missing = false,
  });

  final String id;

  /// Mirrors the chapter filename — never hand-edited on the board.
  final String title;

  /// The manuscript document this board row is linked to. Null on a row
  /// whose chapter vanished (`missing`).
  final String? documentId;

  /// The pending action's kind — the subset the chapter list's dots read.
  final PlanActionKind? action;
  final bool done;

  /// Everything the row carries, verbatim, so a write echoes fields this
  /// client never reads rather than dropping them.
  final Json raw;

  /// The linked chapter's filename at last reconcile.
  final String? filename;

  /// Writer's free notes — the one always-editable text on a row.
  final String notes;

  /// The pending action, whole. `action` is its kind.
  final PlanAction? pending;

  /// Completed actions, oldest first.
  final List<PlanHistoryEntry> history;

  /// The chapter vanished from the manuscript without a delete action.
  final bool missing;

  /// The visible title: the filename minus `.md`.
  String get label => title.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');

  static PlanChapter fromJson(Json json) {
    final pending = json['action'] is Map ? PlanAction.fromJson(asJson(json['action'])) : null;
    final history = asJsonList(json['history']).map(PlanHistoryEntry.fromJson).nonNulls.toList();
    // `done` joined the row shape after v2 shipped: a row without it whose
    // last completed action was the line edit was finished under the old
    // rules too (desktop `withDone`).
    final done = json['done'] is bool
        ? json['done'] as bool
        : history.isNotEmpty && history.last.kind == PlanActionKind.lineEdit;
    return PlanChapter(
      id: asString(json['id']),
      title: asString(json['title']),
      documentId: json['document_id'] as String?,
      action: pending?.kind,
      done: done,
      raw: json,
      filename: json['filename'] as String?,
      notes: asString(json['notes']),
      pending: pending,
      history: history,
      missing: asBool(json['missing']),
    );
  }

  /// A new row over a manuscript chapter. Rows are minted by the board's
  /// seed and reconcile; the id is the caller's (a uuid).
  factory PlanChapter.linked({
    required String id,
    required String documentId,
    required String filename,
    required PlanAction? action,
  }) =>
      PlanChapter.fromJson({
        'id': id,
        'title': filename,
        'document_id': documentId,
        'filename': filename,
        'notes': '',
        'action': action?.toJson(),
        'history': const <Json>[],
        'done': false,
        'missing': false,
      });

  /// `action` assigns a fresh, unanchored action of that kind (and clears
  /// `done` — a chapter with work owed isn't finished); `pending` writes an
  /// action whole; `clearAction` drops it.
  PlanChapter copyWith({
    String? title,
    PlanActionKind? action,
    PlanAction? pending,
    bool clearAction = false,
    bool? done,
    String? documentId,
    bool clearDocument = false,
    String? filename,
    String? notes,
    List<PlanHistoryEntry>? history,
    bool? missing,
  }) {
    final next = Map<String, dynamic>.from(raw);
    if (title != null) next['title'] = title;
    if (clearAction) {
      next['action'] = null;
    } else if (pending != null) {
      next['action'] = pending.toJson();
    } else if (action != null) {
      next['action'] = PlanAction.fresh(action, DateTime.now().toUtc().toIso8601String()).toJson();
      next['done'] = false;
    }
    if (done != null) next['done'] = done;
    if (clearDocument) {
      next['document_id'] = null;
      next['filename'] = null;
    } else {
      if (documentId != null) next['document_id'] = documentId;
      if (filename != null) next['filename'] = filename;
    }
    if (notes != null) next['notes'] = notes;
    if (history != null) next['history'] = history.map((h) => h.toJson()).toList();
    if (missing != null) next['missing'] = missing;
    return PlanChapter.fromJson(next);
  }

  Json toJson() => raw;
}

class ProjectPlan {
  const ProjectPlan({
    required this.formatVersion,
    required this.chapters,
    required this.raw,
    this.seededAt,
    this.reconciledAt,
  });

  final int formatVersion;

  /// Array order is the board order, which is manuscript order.
  final List<PlanChapter> chapters;
  final Json raw;
  final String? seededAt;

  /// Last time the board was held against the manuscript.
  final String? reconciledAt;

  static ProjectPlan fromJson(Json json) => ProjectPlan(
        formatVersion: asInt(json['format_version']),
        chapters: asJsonList(json['chapters']).map(PlanChapter.fromJson).toList(),
        raw: json,
        seededAt: json['seeded_at'] as String?,
        reconciledAt: json['reconciled_at'] as String?,
      );

  /// A plan listed fresh from the manuscript.
  factory ProjectPlan.seeded(List<PlanChapter> chapters, String now) => ProjectPlan.fromJson({
        'format_version': planFormatVersion,
        'seeded_at': now,
        'reconciled_at': now,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      });

  ProjectPlan withChapters(List<PlanChapter> next, {String? reconciledAt}) {
    final json = Map<String, dynamic>.from(raw);
    json['chapters'] = next.map((c) => c.toJson()).toList();
    if (reconciledAt != null) json['reconciled_at'] = reconciledAt;
    return ProjectPlan.fromJson(json);
  }

  Json toJson() => raw;
}
