import 'chat.dart';
import 'json.dart';

// A conversation the server keeps (2026-09-29): its messages, the send's
// answer, the read, and the two realtime shapes that follow it —
// `chat_message` (a row added or its status moved; never the text) and
// `chat_stream` (a running answer's words, steps, views and status beat).
// Hand-written against the contract's ChatMessage / ChatSendResult /
// listChatMessages / ProjectChangeEvent. Every enum reads a value it does not
// know as `unknown` (or the quiet default) rather than throwing: the server's
// vocabulary grows ahead of installed builds.

enum ChatRole {
  user,
  assistant,
  task,
  unknown;

  static ChatRole fromWire(Object? value) => switch (value) {
        'user' => ChatRole.user,
        'assistant' => ChatRole.assistant,
        'task' => ChatRole.task,
        _ => ChatRole.unknown,
      };
}

/// One status across the three roles. user: queued | answered. assistant:
/// running | done | stopped | error. task: its job's — running | done |
/// error | cancelled | gone.
enum ChatMessageStatus {
  queued,
  answered,
  running,
  done,
  stopped,
  error,
  cancelled,
  gone,
  unknown;

  static ChatMessageStatus fromWire(Object? value) =>
      ChatMessageStatus.values.where((s) => s != unknown && s.name == value).firstOrNull ?? unknown;
}

/// One message in a conversation, as the server recorded it.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.seq,
    required this.role,
    required this.status,
    required this.text,
    this.replyTo,
    this.jobId,
    this.attachments = const [],
    this.questions = const [],
    this.steps = const [],
    this.result,
    this.label,
    this.summary,
    this.error,
  });

  final String id;
  final String sessionId;
  final int seq;
  final ChatRole role;
  final ChatMessageStatus status;

  /// The words. A running answer's as far as the last flush.
  final String text;

  /// An answer's: the newest of the messages it answers.
  final String? replyTo;

  /// The job behind an answer (its turn — what Stop cancels) or a task.
  final String? jobId;
  final List<ChatAttachment> attachments;

  /// What an answer stopped to ask.
  final List<ChatQuestion> questions;

  /// An answer's tool steps, as they ran.
  final List<ChatToolStep> steps;

  /// A finished answer's receipts.
  final ChatAnswerResult? result;

  /// A task's label ("Updating the outline").
  final String? label;

  /// A finished task's one line.
  final String? summary;

  /// A failed answer's (or task's) wire code — never shown as is.
  final String? error;

  bool get isRunningAnswer => role == ChatRole.assistant && status == ChatMessageStatus.running;

  static ChatMessage fromJson(Json json) => ChatMessage(
        id: asString(json['id']),
        sessionId: asString(json['session_id']),
        seq: asInt(json['seq']),
        role: ChatRole.fromWire(json['role']),
        status: ChatMessageStatus.fromWire(json['status']),
        text: asString(json['text']),
        replyTo: nonEmptyString(json['reply_to']),
        jobId: nonEmptyString(json['job_id']),
        attachments: _maps(json['attachments']).map(ChatAttachment.fromJson).toList(),
        questions: ChatQuestion.listFromJson(json['questions']),
        steps: _maps(json['steps']).map(ChatToolStep.fromJson).toList(),
        result: ChatAnswerResult.fromJson(json['result']),
        label: nonEmptyString(json['label']),
        summary: nonEmptyString(json['summary']),
        error: nonEmptyString(json['error']),
      );
}

/// GET /chat/sessions/{sid}/messages — the conversation as it stands.
class ChatConversation {
  const ChatConversation({required this.session, required this.status, required this.messages});
  final ChatSession session;
  final ConversationStatus status;
  final List<ChatMessage> messages;

  static ChatConversation fromJson(Json json) => ChatConversation(
        session: ChatSession.fromJson(asJson(json['session'])),
        status: ConversationStatus.fromWire(json['status']),
        messages: _maps(json['messages']).map(ChatMessage.fromJson).toList(),
      );
}

enum ChatSendStatus {
  /// A turn started for it.
  answering,

  /// The conversation is answering something else and takes this up next.
  queued,

  /// This id was already sent; nothing new happened.
  resent,
  unknown;

  static ChatSendStatus fromWire(Object? value) =>
      ChatSendStatus.values.where((s) => s != unknown && s.name == value).firstOrNull ?? unknown;
}

/// POST /chat/messages — 201 answering | queued, 200 resent.
class ChatSendResult {
  const ChatSendResult({required this.status, required this.message, this.session});
  final ChatSendStatus status;
  final ChatMessage message;
  final ChatSession? session;

  static ChatSendResult fromJson(Json json) => ChatSendResult(
        status: ChatSendStatus.fromWire(json['status']),
        message: ChatMessage.fromJson(asJson(json['message'])),
        session: json['session'] is Map ? ChatSession.fromJson(asJson(json['session'])) : null,
      );
}

/// `entity: "chat_message"` — a message was added to [sessionId], or its
/// status moved. No text: a client showing the conversation re-reads it.
class ChatMessageEvent {
  const ChatMessageEvent({required this.sessionId, required this.id, required this.role, required this.status});
  final String sessionId;
  final String id;
  final ChatRole role;
  final ChatMessageStatus status;

  static ChatMessageEvent fromJson(Json json) => ChatMessageEvent(
        sessionId: asString(json['session_id']),
        id: asString(json['id']),
        role: ChatRole.fromWire(json['role']),
        status: ChatMessageStatus.fromWire(json['status']),
      );
}

enum AnswerPhase {
  thinking,
  tool,
  writing,
  unknown;

  static AnswerPhase fromWire(Object? value) =>
      AnswerPhase.values.where((p) => p != unknown && p.name == value).firstOrNull ?? unknown;
}

/// `entity: "chat_stream"` — one frame of a running answer ([id]), numbered
/// per answer from 1 ([n]). Exactly one kind of content per frame.
sealed class ChatStreamFrame {
  const ChatStreamFrame({required this.sessionId, required this.id, required this.n});
  final String sessionId;
  final String id;
  final int n;

  static ChatStreamFrame fromJson(Json json) {
    final sessionId = asString(json['session_id']);
    final id = asString(json['id']);
    final n = asInt(json['n']);
    if (json['text'] is String) {
      return StreamText(sessionId: sessionId, id: id, n: n, text: json['text'] as String, at: json['at'] is num ? asInt(json['at']) : null);
    }
    if (json['discard'] == true) return StreamDiscard(sessionId: sessionId, id: id, n: n);
    if (json['step'] is Map) return StreamStep(sessionId: sessionId, id: id, n: n, step: ChatToolStep.fromJson(asJson(json['step'])));
    if (json.containsKey('view')) return StreamView(sessionId: sessionId, id: id, n: n, view: ChatView.fromJson(json['view']));
    if (json['phase'] != null) {
      return StreamBeat(
        sessionId: sessionId,
        id: id,
        n: n,
        phase: AnswerPhase.fromWire(json['phase']),
        elapsedMs: asInt(json['elapsed_ms']),
        steps: asInt(json['steps']),
        textLength: asInt(json['text_length']),
      );
    }
    return StreamOther(sessionId: sessionId, id: id, n: n);
  }
}

/// Words to add. [at] is where in the answer they start — null only from a
/// server that predates it, and then they append.
class StreamText extends ChatStreamFrame {
  const StreamText({required super.sessionId, required super.id, required super.n, required this.text, this.at});
  final String text;
  final int? at;
}

/// The words so far are not the answer — clear them.
class StreamDiscard extends ChatStreamFrame {
  const StreamDiscard({required super.sessionId, required super.id, required super.n});
}

/// A tool step starting or finishing — upsert by tool + summary.
class StreamStep extends ChatStreamFrame {
  const StreamStep({required super.sessionId, required super.id, required super.n, required this.step});
  final ChatToolStep step;
}

/// A tool opened this beside the conversation (already on the session row).
/// Null for a kind this app does not know.
class StreamView extends ChatStreamFrame {
  const StreamView({required super.sessionId, required super.id, required super.n, required this.view});
  final ChatView? view;
}

/// The status beat, every 10 s while the answer is written.
class StreamBeat extends ChatStreamFrame {
  const StreamBeat({
    required super.sessionId,
    required super.id,
    required super.n,
    required this.phase,
    required this.elapsedMs,
    required this.steps,
    required this.textLength,
  });
  final AnswerPhase phase;
  final int elapsedMs;
  final int steps;
  final int textLength;
}

/// A frame of a shape this app does not know. It still counts toward [n].
class StreamOther extends ChatStreamFrame {
  const StreamOther({required super.sessionId, required super.id, required super.n});
}

List<Json> _maps(Object? value) => [for (final v in value is List ? value : const []) if (v is Map) v.cast<String, dynamic>()];
