import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/chat/api.dart';
import '../server/dto/chat.dart';
import '../server/dto/work_plan.dart';
import 'turn.dart';

// PhantomMemory's providers: the saved sessions of a project, and the one
// turn owner the drawer and the thread both drive. Kept out of
// server/providers.dart because nothing outside the room reads them.

/// The project's saved chats, newest first as the server lists them. A
/// mutation calls the api and invalidates this.
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

/// The turn owner, one per open room: the drawer (sessions list) and the
/// screen (thread) are siblings under the room's Scaffold and both drive the
/// same conversation. Auto-disposed so leaving the room ends the stream and
/// the next visit starts on a fresh chat, as the RN room did on unmount.
final chatTurnProvider = NotifierProvider.autoDispose.family<ChatTurnNotifier, ChatTurnState, String>(
  ChatTurnNotifier.new,
);
