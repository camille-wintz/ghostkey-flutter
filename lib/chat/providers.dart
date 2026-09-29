import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/chat/api.dart';
import '../server/dto/chat.dart';
import '../server/dto/work_plan.dart';
import 'conversation.dart';

// PhantomMemory's providers: the saved sessions of a project, and the one
// conversation owner the drawer and the thread both drive. Kept out of
// server/providers.dart because nothing outside the room reads them.

/// The project's saved chats, newest first as the server lists them, each
/// with whether it is answering. A mutation calls the api and invalidates
/// this; so does the conversation owner on a chat event.
final chatSessionsProvider = FutureProvider.family<List<ChatSessionSummary>, String>(
  (ref, projectId) => listSessions(projectId),
);

/// The project's work plans, newest first, each with the conversations under
/// it. Invalidated beside [chatSessionsProvider]: a plan's mutation, and a
/// turn that started or took one up, move both.
final workPlansProvider = FutureProvider.family<List<WorkPlanSummary>, String>(
  (ref, projectId) => listWorkPlans(projectId),
);

/// One plan with its text, for the page that edits it. Read once on open.
final workPlanProvider = FutureProvider.autoDispose.family<WorkPlan, ({String projectId, String planId})>(
  (ref, key) => getWorkPlan(key.projectId, key.planId),
);

/// The conversation owner, one per open room: the drawer (sessions list) and
/// the screen (thread) are siblings under the room's Scaffold and both drive
/// the same conversation. Auto-disposed so leaving the room stops following
/// it — the server goes on answering — and the next visit starts on a fresh
/// chat.
final conversationProvider =
    NotifierProvider.autoDispose.family<ConversationNotifier, ConversationState, String>(ConversationNotifier.new);
