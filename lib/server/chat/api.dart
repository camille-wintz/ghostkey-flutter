import '../client.dart';
import '../dto/chat.dart';
import '../dto/chat_conversation.dart';
import '../dto/json.dart';
import '../dto/work_plan.dart';

// /api/projects/:id/chat/* — sessions, messages and the conversation read.
// The chat's whole engine (prompts, tools, model protocols, the transcript
// itself) is server-side; this file only speaks the wire shapes in
// ../dto/chat.dart and ../dto/chat_conversation.dart.

String _base(String projectId) => '/api/projects/${Uri.encodeComponent(projectId)}/chat';

Future<List<ChatSessionSummary>> listSessions(String projectId) async {
  final res = await apiFetch('${_base(projectId)}/sessions');
  return asJsonList(res.jsonObject()['sessions']).map(ChatSessionSummary.fromJson).toList();
}

/// An empty conversation, for a door that opens the chat on a subject (a
/// scene, the chapter plan) before anything is said in it. A first message
/// sent with no session makes its own — see [sendMessage].
Future<ChatSession> createSession(String projectId, {required String title, ChatView? view}) async {
  final res = await apiFetch('${_base(projectId)}/sessions',
      method: 'POST', body: {'title': title, 'view': ?view?.toJson()});
  return ChatSession.fromJson(asJson(res.jsonObject()['session']));
}

/// `workPlanId` moves the conversation under a plan; this app never moves one
/// out, so null means "leave it". The transcript is the server's: a PATCH
/// never carries messages.
Future<ChatSession> patchSession(
  String projectId,
  String sessionId, {
  String? title,
  String? workPlanId,
}) async {
  final res = await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}', method: 'PATCH', body: {
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

/// Ask the server to reflect over sessions updated since the last pass. It
/// gates on staleness itself, so calling it on every room open is cheap.
Future<void> postReflect(String projectId) async {
  await apiFetch('/api/projects/${Uri.encodeComponent(projectId)}/memory/reflect',
      method: 'POST', body: const <String, dynamic>{});
}

/// Send a message — the author's words, recorded before any model runs and
/// answered by the server whether or not this app stays to watch. [id] is the
/// client's and makes a resend the same message (200 `resent`), so a send
/// that failed on the network is retried with the id it had. No [sessionId]:
/// the message starts a conversation, created under [workPlanId] with [view]
/// beside it. A 402 / 403 refusal records nothing and throws the
/// [ServerError] the client parses (`quota` / `denial`).
Future<ChatSendResult> sendMessage(
  String projectId, {
  required String id,
  String? sessionId,
  required String text,
  List<ChatAttachment> attachments = const [],
  String? model,
  required String manuscript,
  ChatView? view,
  String? workPlanId,
}) async {
  final res = await apiFetch('${_base(projectId)}/messages',
      method: 'POST',
      body: sendMessageBody(
        id: id,
        sessionId: sessionId,
        text: text,
        attachments: attachments,
        model: model,
        manuscript: manuscript,
        view: view,
        workPlanId: workPlanId,
      ));
  return ChatSendResult.fromJson(res.jsonObject());
}

/// The send's body. [view] and [workPlanId] belong to a conversation the
/// message starts, so they go only without a [sessionId]; `manuscript`
/// ("write" / "read_only") goes every time — the server's default is
/// read-only, the app's is write.
Json sendMessageBody({
  required String id,
  String? sessionId,
  required String text,
  List<ChatAttachment> attachments = const [],
  String? model,
  required String manuscript,
  ChatView? view,
  String? workPlanId,
}) =>
    {
      'id': id,
      'session_id': ?sessionId,
      'text': text,
      if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toJson()).toList(),
      'model': ?model,
      'manuscript': manuscript,
      // The phone has no desk beside the chat, but what a tool opens is still
      // where its work landed: the Review button seats it on demand.
      'views': 'beside',
      if (sessionId == null) 'view': ?view?.toJson(),
      if (sessionId == null) 'work_plan_id': ?workPlanId,
    };

/// The conversation as it stands: every message in order, a running answer
/// with its words and steps so far, each task with its job's status.
Future<ChatConversation> readConversation(String projectId, String sessionId) async {
  final res = await apiFetch('${_base(projectId)}/sessions/${Uri.encodeComponent(sessionId)}/messages');
  return ChatConversation.fromJson(res.jsonObject());
}
