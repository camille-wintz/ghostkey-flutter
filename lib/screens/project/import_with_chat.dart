import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/quota_refusals.dart';
import '../../chat/arrival.dart';
import '../../chat/providers.dart';
import '../../chat/quota_feature.dart';
import '../../rooms/rooms.dart';
import '../../server/chat/api.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/lock_notice.dart';
import '../../ui/notice_modal.dart';
import '../phantom/phantom_screen.dart';

/// What a failed import's file is sent with — the desk's words, so the chat
/// meets the same request from either.
const String importWithChatAsk = 'Help me process and import this file.';

/// A failed import's way on: the book's chat, in a fresh conversation, with
/// the file attached and [importWithChatAsk] sent. The desk's
/// `useImportWithChat`.
///
/// Gated as [planChaptersInChat] gates the chat: the room, then the chat's
/// allowance for a fresh conversation on the default model. [navigator] is
/// the book's own — the chat only lives inside it.
Future<void> importWithChat(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ChatLanding file,
  required NavigatorState navigator,
}) async {
  final chat = ref.read(capabilityProvider(roomFor(RoomKey.phantom).capability));
  if (!chat.granted) return explainLock(context, chat, roomFor(RoomKey.phantom).title);
  final snapshot = ref.read(quotaProvider).value;
  final quota = chatQuotaFor(snapshot);
  if (quota.exhausted) return reportQuotaSpent(quota.feature, snapshot: snapshot);

  try {
    final session = await createSession(projectId, title: file.title.trim().isEmpty ? 'Import' : file.title);
    ref.invalidate(chatSessionsProvider(projectId));
    await navigator.pushNamed(
      PhantomScreen.route,
      arguments: ChatArrival(sessionId: session.id, ask: importWithChatAsk, attach: file),
    );
  } catch (e) {
    if (!context.mounted) return;
    await showNoticeModal(
      context,
      eyebrow: 'Import',
      title: "Couldn't open the chat.",
      action: 'OK',
      children: [NoticeText('The file is in the library, and the chat can still take it. ${messageFor(e)}')],
    );
  }
}
