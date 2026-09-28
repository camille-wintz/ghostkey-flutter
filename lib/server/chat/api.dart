import 'dart:async';
import 'dart:convert';

import '../client.dart';
import '../dto/chat.dart';
import '../dto/json.dart';
import '../dto/work_plan.dart';
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

/// The create's body. `workPlanId` is the plan the first turn started or
/// took up — this app creates the session after that turn, so the server had
/// no row to attach it to.
Json sessionCreateBody({required String title, List<ChatMessage>? messages, ChatView? view, String? workPlanId}) => {
      'title': title,
      'messages': ?messages?.map((m) => m.toJson()).toList(),
      'view': ?view?.toJson(),
      'work_plan_id': ?workPlanId,
    };

Future<ChatSession> createSession(
  String projectId, {
  required String title,
  List<ChatMessage>? messages,
  ChatView? view,
  String? workPlanId,
}) async {
  final res = await apiFetch('${_base(projectId)}/sessions',
      method: 'POST', body: sessionCreateBody(title: title, messages: messages, view: view, workPlanId: workPlanId));
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

/// `workPlanId` moves the conversation under a plan; this app never moves one
/// out, so null means "leave it".
Future<ChatSession> patchSession(
  String projectId,
  String sessionId, {
  List<ChatMessage>? messages,
  String? title,
  String? workPlanId,
}) async {
  final res = await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}', method: 'PATCH', body: {
    'messages': ?messages?.map((m) => m.toJson()).toList(),
    'title': ?title,
    'work_plan_id': ?workPlanId,
  });
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

Future<void> deleteSession(String projectId, String sessionId) async {
  await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}', method: 'DELETE');
}

String _plans(String projectId) => '/api/projects/${Uri.encodeComponent(projectId)}/work-plans';

/// The project's work plans, most recently changed first.
Future<List<WorkPlanSummary>> listWorkPlans(String projectId) async {
  final res = await apiFetch(_plans(projectId));
  return asJsonList(res.jsonObject()['work_plans']).map(WorkPlanSummary.fromJson).toList();
}

Future<WorkPlan> getWorkPlan(String projectId, String planId) async {
  final res = await apiFetch('${_plans(projectId)}/${Uri.encodeComponent(planId)}');
  return WorkPlan.fromJson(asJson(res.jsonObject()['work_plan']));
}

/// `text` omitted, the plan starts with its empty headings.
Future<WorkPlan> createWorkPlan(String projectId, {required String name, String? text}) async {
  final res = await apiFetch(_plans(projectId), method: 'POST', body: {'name': name, 'text': ?text});
  return WorkPlan.fromJson(asJson(res.jsonObject()['work_plan']));
}

/// Rename and/or save the text. `baseVersion` makes a text save conditional:
/// a miss is 409 `version_conflict` (the chat wrote the plan meanwhile).
Future<WorkPlan> patchWorkPlan(String projectId, String planId, {String? name, String? text, int? baseVersion}) async {
  final res = await apiFetch('${_plans(projectId)}/${Uri.encodeComponent(planId)}', method: 'PATCH', body: {
    'name': ?name,
    'text': ?text,
    'base_version': ?baseVersion,
  });
  return WorkPlan.fromJson(asJson(res.jsonObject()['work_plan']));
}

/// For good. Its conversations stay, under no plan.
Future<void> deleteWorkPlan(String projectId, String planId) async {
  await apiFetch('${_plans(projectId)}/${Uri.encodeComponent(planId)}', method: 'DELETE');
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
  /// Whether this turn may edit chapters — "write" or "read_only". Sent
  /// every turn: the server's default is read-only, the app's is write.
  String? manuscript,
  String? sessionId,
  /// What is open beside a conversation that has no session yet — a work
  /// plan the author started it from. With a session the server reads the
  /// row's own view and ignores this.
  ChatView? view,
  required void Function(ChatToolStep step) onStep,
  required void Function(String chunk) onText,
  required void Function() onDiscard,
  required void Function(ChatView view) onView,
}) async {
  final res = await apiStream(
    '${_base(projectId)}/turn',
    method: 'POST',
    headers: const {'Accept': 'text/event-stream'},
    body: {
      'messages': messages.map((m) => m.toJson()).toList(),
      'model': ?model,
      'manuscript': ?manuscript,
      'session_id': ?sessionId,
      if (sessionId == null) 'view': ?view?.toJson(),
      // The phone has no desk beside the chat, but what a tool opens is
      // still where its work landed: the Review button seats it on demand.
      'views': 'beside',
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
        case ViewFrame(:final view?):
          onView(view);
        case ViewFrame():
          break;
        case TextFrame(:final text):
          onText(text);
        case DiscardFrame():
          onDiscard();
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
