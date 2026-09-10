import 'json.dart';

// PhantomMemory chat. Hand-written against the contract's ChatSession* /
// ChatTurn* / ChatToolStep / ChatAttachment schemas.

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

enum ChatRole {
  user,
  assistant;

  static ChatRole fromWire(String? value) => value == 'assistant' ? ChatRole.assistant : ChatRole.user;
}

/// One turn of a saved transcript.
class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.attachments = const []});
  final ChatRole role;
  final String text;
  final List<ChatAttachment> attachments;

  static ChatMessage fromJson(Json json) => ChatMessage(
        role: ChatRole.fromWire(json['role'] as String?),
        text: asString(json['text']),
        attachments: asJsonList(json['attachments']).map(ChatAttachment.fromJson).toList(),
      );

  Json toJson() => {
        'role': role.name,
        'text': text,
        if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.title,
    required this.version,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final int version;
  final String updatedAt;

  static ChatSessionSummary fromJson(Json json) => ChatSessionSummary(
        id: asString(json['id']),
        title: asString(json['title']),
        version: asInt(json['version']),
        updatedAt: asString(json['updated_at']),
      );
}

class ChatSession extends ChatSessionSummary {
  const ChatSession({
    required super.id,
    required super.title,
    required super.version,
    required super.updatedAt,
    required this.projectId,
    required this.messages,
    required this.createdAt,
  });
  final String projectId;
  final List<ChatMessage> messages;
  final String createdAt;

  static ChatSession fromJson(Json json) => ChatSession(
        id: asString(json['id']),
        title: asString(json['title']),
        version: asInt(json['version']),
        updatedAt: asString(json['updated_at']),
        projectId: asString(json['project_id']),
        messages: asJsonList(json['messages']).map(ChatMessage.fromJson).toList(),
        createdAt: asString(json['created_at']),
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

/// What a turn wrote into the project besides notes.
class ChatTurnEdits {
  const ChatTurnEdits({required this.chapterEdits, required this.bibleEdits});
  final List<ChatChapterEdit> chapterEdits;
  final List<ChatBibleEdit> bibleEdits;
  bool get isEmpty => chapterEdits.isEmpty && bibleEdits.isEmpty;
}

/// The `result` frame of a turn. `session` is the updated row when
/// `session_id` was sent and the write landed; null otherwise.
class ChatTurnResult {
  const ChatTurnResult({
    required this.answer,
    required this.steps,
    required this.savedNotes,
    required this.session,
    this.chapterEdits = const [],
    this.bibleEdits = const [],
  });
  final String answer;
  final List<ChatToolStep> steps;
  final List<ChatSavedNote> savedNotes;
  final ChatSession? session;
  final List<ChatChapterEdit> chapterEdits;
  final List<ChatBibleEdit> bibleEdits;

  ChatTurnEdits get edits => ChatTurnEdits(chapterEdits: chapterEdits, bibleEdits: bibleEdits);

  static ChatTurnResult fromJson(Json json) => ChatTurnResult(
        answer: asString(json['answer']),
        steps: asJsonList(json['steps']).map(ChatToolStep.fromJson).toList(),
        savedNotes: asJsonList(json['savedNotes']).map(ChatSavedNote.fromJson).toList(),
        session: json['session'] == null ? null : ChatSession.fromJson(asJson(json['session'])),
        chapterEdits: asJsonList(json['chapterEdits']).map(ChatChapterEdit.fromJson).toList(),
        bibleEdits: asJsonList(json['bibleEdits']).map(ChatBibleEdit.fromJson).toList(),
      );
}

/// One `data:` line of the turn stream, decoded.
sealed class ChatTurnFrame {
  const ChatTurnFrame();

  static ChatTurnFrame fromJson(Json json) {
    if (json['step'] is Map) return StepFrame(ChatToolStep.fromJson(asJson(json['step'])));
    if (json['result'] is Map) return ResultFrame(ChatTurnResult.fromJson(asJson(json['result'])));
    if (json['error'] is String) return ErrorFrame(asString(json['error']), json['detail'] as String?);
    return TextFrame(asString(json['text']));
  }
}

class StepFrame extends ChatTurnFrame {
  const StepFrame(this.step);
  final ChatToolStep step;
}

class TextFrame extends ChatTurnFrame {
  const TextFrame(this.text);
  final String text;
}

class ResultFrame extends ChatTurnFrame {
  const ResultFrame(this.result);
  final ChatTurnResult result;
}

class ErrorFrame extends ChatTurnFrame {
  const ErrorFrame(this.error, this.detail);
  final String error;
  final String? detail;
}
