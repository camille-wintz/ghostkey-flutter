import 'json.dart';

// PhantomMemory chat: sessions, attachments, views, tool steps and the
// receipts an answer carries. Hand-written against the contract's
// ChatSession* / ChatToolStep / ChatAttachment schemas; the messages of a
// conversation and their live events are in chat_conversation.dart.

/// `id` is a short handle (`a1`, `a2`, …) unique within the whole session.
sealed class ChatAttachment {
  const ChatAttachment({required this.id, required this.title});
  final String id;
  final String title;

  Json toJson();

  static ChatAttachment fromJson(Json json) => switch (json['kind']) {
        'paste' => PasteAttachment(
            id: asString(json['id']),
            title: asString(json['title']),
            words: asInt(json['words']),
            text: asString(json['text']),
          ),
        'file' => FileAttachment(
            id: asString(json['id']),
            title: asString(json['title']),
            itemId: asString(json['item_id']),
            words: json['words'] as int?,
          ),
        _ => ChapterAttachment(
            id: asString(json['id']),
            title: asString(json['title']),
            documentId: asString(json['document_id']),
            words: json['words'] as int?,
          ),
      };
}

/// A file the author uploaded — a .docx, a .pdf, a text file. Its text is a
/// media library item (the upload made it, origin "chat"); this carries the
/// item's id and no body, so a book-length file never rides the transcript.
class FileAttachment extends ChatAttachment {
  const FileAttachment({
    required super.id,
    required super.title,
    required this.itemId,
    this.words,
  });
  final String itemId;
  final int? words;

  @override
  Json toJson() => {
        'kind': 'file',
        'id': id,
        'title': title,
        'item_id': itemId,
        if (words != null) 'words': words,
      };
}

/// A chapter attached by id — the document is the body, read by the server.
class ChapterAttachment extends ChatAttachment {
  const ChapterAttachment({
    required super.id,
    required super.title,
    required this.documentId,
    this.words,
  });
  final String documentId;
  final int? words;

  @override
  Json toJson() => {
        'kind': 'chapter',
        'id': id,
        'title': title,
        'document_id': documentId,
        if (words != null) 'words': words,
      };
}

/// A long paste. Persisted with the transcript: it lives nowhere else.
class PasteAttachment extends ChatAttachment {
  const PasteAttachment({
    required super.id,
    required super.title,
    required this.words,
    required this.text,
  });
  final int words;
  final String text;

  @override
  Json toJson() => {'kind': 'paste', 'id': id, 'title': title, 'words': words, 'text': text};
}

/// One question a turn stopped to ask (ChatTurnPlan.questions), with the
/// answers it suggests as taps. Never the whole answer: free text stays open.
class ChatQuestion {
  const ChatQuestion({required this.question, this.options = const []});
  final String question;
  final List<String> options;

  static ChatQuestion fromJson(Json json) => ChatQuestion(
        question: asString(json['question']),
        options: [for (final o in json['options'] as List? ?? const []) if (o is String) o],
      );

  static List<ChatQuestion> listFromJson(Object? json) =>
      asJsonList(json is List ? json : null).map(ChatQuestion.fromJson).toList();

  Json toJson() => {'question': question, 'options': options};
}

class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.title,
    required this.version,
    required this.updatedAt,
    this.workPlanId,
    this.status = ConversationStatus.idle,
  });
  final String id;
  final String title;
  final int version;
  final String updatedAt;

  /// The work plan this conversation works under, or null.
  final String? workPlanId;

  /// Whether it is answering — the list's; a single session's read leaves
  /// it idle (the conversation read carries its own).
  final ConversationStatus status;

  static ChatSessionSummary fromJson(Json json) => ChatSessionSummary(
        id: asString(json['id']),
        title: asString(json['title']),
        version: asInt(json['version']),
        updatedAt: asString(json['updated_at']),
        workPlanId: nonEmptyString(json['work_plan_id']),
        status: ConversationStatus.fromWire(json['status']),
      );
}

/// A conversation's state: answering (`running`), a message waiting with
/// nothing answering it yet (`queued`), or neither. Anything else reads idle.
enum ConversationStatus {
  idle,
  running,
  queued;

  static ConversationStatus fromWire(Object? value) => switch (value) {
        'running' => ConversationStatus.running,
        'queued' => ConversationStatus.queued,
        _ => ConversationStatus.idle,
      };
}

/// What a turn opened for the author to look at: a chapter (`id` is the
/// document id), one of their boards (`id` is the StoryMap id), the Outline
/// page or the Chapters page (neither carries an id), or a picture (`id` is
/// the media item id), or a work plan (`id` is the plan id). The desk seats
/// it beside
/// the conversation; the phone reviews it behind a button. `title` is a
/// courtesy for a header; the id is the address.
class ChatView {
  const ChatView({required this.kind, this.id, this.title});
  final ChatViewKind kind;
  final String? id;
  final String? title;

  /// Null for a shape this client does not know — read as nothing open.
  static ChatView? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = ChatViewKind.values.where((k) => k.wire == json['kind']).firstOrNull;
    if (kind == null) return null;
    return ChatView(kind: kind, id: json['id'] as String?, title: json['title'] as String?);
  }

  Json toJson() => {'kind': kind.wire, 'id': ?id, 'title': ?title};
}

enum ChatViewKind {
  chapter('chapter'),
  board('board'),
  outline('outline'),
  chapters('chapters'),
  image('image'),
  workPlan('work_plan');

  const ChatViewKind(this.wire);
  final String wire;
}

class ChatSession extends ChatSessionSummary {
  const ChatSession({
    required super.id,
    required super.title,
    required super.version,
    required super.updatedAt,
    required this.projectId,
    required this.createdAt,
    super.workPlanId,
    this.view,
  });
  final String projectId;
  final String createdAt;
  final ChatView? view;

  static ChatSession fromJson(Json json) => ChatSession(
        id: asString(json['id']),
        title: asString(json['title']),
        version: asInt(json['version']),
        updatedAt: asString(json['updated_at']),
        projectId: asString(json['project_id']),
        createdAt: asString(json['created_at']),
        workPlanId: nonEmptyString(json['work_plan_id']),
        view: ChatView.fromJson(json['view']),
      );
}

enum ChatToolStepStatus {
  running,
  done,
  error;

  static ChatToolStepStatus fromWire(String? value) => switch (value) {
        'done' => ChatToolStepStatus.done,
        'error' => ChatToolStepStatus.error,
        _ => ChatToolStepStatus.running,
      };
}

/// One tool call inside a turn, streamed as a `step` frame first `running`,
/// then `done` / `error`. Clients upsert by `tool` + `summary`.
class ChatToolStep {
  const ChatToolStep({
    required this.tool,
    required this.summary,
    required this.status,
    this.detail,
    this.error,
  });
  final String tool;
  final String summary;
  final ChatToolStepStatus status;
  final String? detail;
  final String? error;

  static ChatToolStep fromJson(Json json) => ChatToolStep(
        tool: asString(json['tool']),
        summary: asString(json['summary']),
        status: ChatToolStepStatus.fromWire(json['status'] as String?),
        detail: json['detail'] as String?,
        error: json['error'] as String?,
      );
}

class ChatSavedNote {
  const ChatSavedNote({required this.documentId, required this.filename});
  final String documentId;
  final String filename;

  static ChatSavedNote fromJson(Json json) => ChatSavedNote(
        documentId: asString(json['documentId']),
        filename: asString(json['filename']),
      );
}

/// A chapter the turn wrote — a passage replaced in place (update_chapter) or
/// a whole chapter added (create_chapter) — already written by the time the
/// turn resolves, through the writes the autosave and a new chapter use. The
/// receipt; `version` is the revision the write produced, and `created` is
/// true for a chapter that was not there before this turn.
class ChatChapterEdit {
  const ChatChapterEdit({
    required this.documentId,
    required this.filename,
    required this.version,
    required this.created,
  });
  final String documentId;
  final String filename;
  final int version;
  final bool created;

  static ChatChapterEdit fromJson(Json json) => ChatChapterEdit(
        documentId: asString(json['documentId']),
        filename: asString(json['filename']),
        version: asInt(json['version']),
        created: json['created'] == true,
      );
}

/// A world-bible card the turn added or edited (update_entity).
class ChatBibleEdit {
  const ChatBibleEdit({required this.entityId, required this.name, required this.created});
  final String entityId;
  final String name;
  final bool created;

  static ChatBibleEdit fromJson(Json json) => ChatBibleEdit(
        entityId: asString(json['entityId']),
        name: asString(json['name']),
        created: json['created'] == true,
      );
}

/// What a finished answer wrote into the project besides notes: chapters and
/// world-bible cards. The changes it handed to tasks are messages of their
/// own in the conversation, not receipts.
class ChatTurnEdits {
  const ChatTurnEdits({required this.chapterEdits, required this.bibleEdits});
  final List<ChatChapterEdit> chapterEdits;
  final List<ChatBibleEdit> bibleEdits;
  bool get isEmpty => chapterEdits.isEmpty && bibleEdits.isEmpty;
}

/// A finished answer's receipts — a ChatMessage's `result`. The fields this
/// app draws; the rest (planEdits, editPasses, awaitingApproval, tasks) are
/// read elsewhere or not at all.
class ChatAnswerResult {
  const ChatAnswerResult({
    this.savedNotes = const [],
    this.chapterEdits = const [],
    this.bibleEdits = const [],
    this.model,
    this.switchedFrom,
    this.workPlanId,
  });
  final List<ChatSavedNote> savedNotes;
  final List<ChatChapterEdit> chapterEdits;
  final List<ChatBibleEdit> bibleEdits;

  /// The registry model that answered.
  final String? model;

  /// The model the author picked, when the answer had to look at a picture
  /// that model can't see and [model] answered instead.
  final String? switchedFrom;

  /// The work plan this answer worked under — started, taken up, or the one
  /// the conversation already had.
  final String? workPlanId;

  ChatTurnEdits get edits => ChatTurnEdits(chapterEdits: chapterEdits, bibleEdits: bibleEdits);

  static ChatAnswerResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = json.cast<String, dynamic>();
    return ChatAnswerResult(
      savedNotes: _list(map['savedNotes']).map(ChatSavedNote.fromJson).toList(),
      chapterEdits: _list(map['chapterEdits']).map(ChatChapterEdit.fromJson).toList(),
      bibleEdits: _list(map['bibleEdits']).map(ChatBibleEdit.fromJson).toList(),
      model: nonEmptyString(map['model']),
      switchedFrom: nonEmptyString(map['switched_from']),
      workPlanId: nonEmptyString(map['workPlanId']),
    );
  }
}

List<Json> _list(Object? value) => [for (final v in value is List ? value : const []) if (v is Map) v.cast<String, dynamic>()];

String? nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;
