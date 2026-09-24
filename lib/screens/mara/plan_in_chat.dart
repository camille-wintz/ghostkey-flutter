import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/quota_refusals.dart';
import '../../chat/arrival.dart';
import '../../chat/models.dart';
import '../../chat/providers.dart';
import '../../chat/quota_feature.dart';
import '../../mara/access.dart';
import '../../rooms/rooms.dart';
import '../../server/chat/api.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/lock_notice.dart';
import '../../ui/notice_modal.dart';
import '../phantom/phantom_screen.dart';

/// Chapters are planned IN THE CHAT: Generate on Cards and Break into
/// chapters on the Outline start nothing here — they open a fresh
/// conversation titled [title] with [ask] sent, and the chat sizes the book,
/// asks about the plan's gaps and writes the chapters itself.
///
/// Gated as the desk's `usePlanChaptersInChat`, outermost first: chapter
/// planning on the plan, then the chat room it happens in, then the chat's
/// allowance for a fresh conversation on the default model. [flush] lands
/// what the page is still holding, since the chat reads the plan off the
/// server.
Future<void> planChaptersInChat(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String title,
  required String ask,
  Future<void> Function()? flush,
}) async {
  final planning = ref.read(capabilityProvider(chapterPlanCapability));
  if (!planning.granted) return explainLock(context, planning, 'Chapter generation');
  final chat = ref.read(capabilityProvider(roomFor(RoomKey.phantom).capability));
  if (!chat.granted) return explainLock(context, chat, roomFor(RoomKey.phantom).title);
  final snapshot = ref.read(quotaProvider).value;
  final quota = chatQuotaFor(snapshot, chatModelRow(ref.read(chatModelsProvider), null));
  if (quota.exhausted) return reportQuotaSpent(quota.feature, snapshot: snapshot);

  final navigator = Navigator.of(context);
  try {
    await flush?.call();
    final session = await createSession(projectId, title: title, messages: const []);
    ref.invalidate(chatSessionsProvider(projectId));
    await navigator.pushNamed(PhantomScreen.route, arguments: ChatArrival(sessionId: session.id, ask: ask));
  } catch (e) {
    if (!context.mounted) return;
    await showNoticeModal(
      context,
      eyebrow: 'Mara',
      title: "Couldn't open the chat to plan the chapters.",
      action: 'OK',
      children: [NoticeText('Check your connection and try again. ${messageFor(e)}')],
    );
  }
}
