import 'dart:async';
import 'dart:convert';

import '../client.dart';
import '../dto/chat.dart';
import '../dto/json.dart';
import '../errors.dart';
import '../sse.dart';

// /api/projects/:id/chat/* — sessions, the title call and the streamed turn.
// The chat's whole engine (prompts, tools, model protocols) is server-side;
// this file only speaks the wire shapes in ../dto/chat.dart.

String _base(String projectId) => '/api/projects/${Uri.encodeComponent(projectId)}/chat';

Future<List<ChatSessionSummary>> listSessions(String projectId) async {
  final res = await apiFetch('${_base(projectId)}/sessions');
  return asJsonList(res.jsonObject()['sessions']).map(ChatSessionSummary.fromJson).toList();
}

Future<ChatSession> getSession(String projectId, String sessionId) async {
  final res = await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}');
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

Future<ChatSession> createSession(String projectId, {required String title, List<ChatMessage>? messages}) async {
  final res = await apiFetch('${_base(projectId)}/sessions', method: 'POST', body: {
    'title': title,
    'messages': ?messages?.map((m) => m.toJson()).toList(),
  });
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

Future<ChatSession> patchSession(String projectId, String sessionId, {List<ChatMessage>? messages, String? title}) async {
  final res = await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}', method: 'PATCH', body: {
    'messages': ?messages?.map((m) => m.toJson()).toList(),
    'title': ?title,
  });
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

Future<void> deleteSession(String projectId, String sessionId) async {
  await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}', method: 'DELETE');
}

/// A short title for a conversation from its opening turns; "" when the model
/// gave nothing usable. Stateless — the caller persists it with a PATCH.
Future<String> suggestTitle(String projectId, List<ChatMessage> turns) async {
  final res = await apiFetch('${_base(projectId)}/title', method: 'POST', body: {
    'turns': turns.take(4).map((t) => {'role': t.role.name, 'text': t.text}).toList(),
  });
  return asString(res.jsonObject()['title']);
}

/// Ask the server to reflect over sessions updated since the last pass. It
/// gates on staleness itself, so calling it on every room open is cheap.
Future<void> postReflect(String projectId) async {
  await apiFetch('/api/projects/${Uri.encodeComponent(projectId)}/memory/reflect',
      method: 'POST', body: const <String, dynamic>{});
}

/// A live turn: the subscription to cancel it, and the result when it ends.
class TurnHandle {
  TurnHandle._(this._subscription, this.result);
  final StreamSubscription<String> _subscription;
  final Future<ChatTurnResult> result;

  /// Stop reading. The server keeps writing the transcript it was given;
  /// the caller's foreground resync reads what it finished without us.
  Future<void> cancel() => _subscription.cancel();
}

/// Run one turn. Failures before the stream opens (400/402/403/429) throw
/// the [ServerError] the client parses — the 402 carries `quota`, the 403
/// `denial`; a failure after it opens arrives as an `error` frame and
/// completes `result` with a status-0 ServerError carrying the frame's code.
Future<TurnHandle> streamTurn(
  String projectId, {
  required List<ChatMessage> messages,
  String? model,
  String? sessionId,
  required void Function(ChatToolStep step) onStep,
  required void Function(String chunk) onText,
}) async {
  final res = await apiStream(
    '${_base(projectId)}/turn',
    method: 'POST',
    headers: const {'Accept': 'text/event-stream'},
    body: {
      'messages': messages.map((m) => m.toJson()).toList(),
      'model': ?model,
      'session_id': ?sessionId,
    },
  );

  final completer = Completer<ChatTurnResult>();
  ChatTurnResult? result;
  ServerError? failure;

  final subscription = readSse(res.stream).listen(
    (payload) {
      final Json json;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) return;
        json = decoded;
      } catch (_) {
        return;
      }
      switch (ChatTurnFrame.fromJson(json)) {
        case StepFrame(:final step):
          onStep(step);
        case TextFrame(:final text):
          onText(text);
        case ResultFrame(result: final r):
          result = r;
        case ErrorFrame(:final error, :final detail):
          failure = ServerError(error, 0, detail ?? error);
      }
    },
    onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e is ServerError ? e : ServerError('network_error', 0, e.toString()));
    },
    onDone: () {
      if (completer.isCompleted) return;
      if (failure != null) {
        completer.completeError(failure!);
      } else if (result == null) {
        completer.completeError(ServerError('empty_response', 0, 'The turn ended without a result frame.'));
      } else {
        completer.complete(result);
      }
    },
    cancelOnError: true,
  );

  return TurnHandle._(subscription, completer.future);
}
