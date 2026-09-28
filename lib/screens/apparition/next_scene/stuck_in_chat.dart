import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/capability.dart';
import '../../../access/quota_refusals.dart';
import '../../../chat/arrival.dart';
import '../../../chat/models.dart';
import '../../../chat/providers.dart';
import '../../../chat/quota_feature.dart';
import '../../../rooms/rooms.dart';
import '../../../server/chat/api.dart';
import '../../../server/dto/chat.dart';
import '../../../server/dto/next_scene.dart';
import '../../../server/errors.dart';
import '../../../server/providers.dart';
import '../../../ui/lock_notice.dart';
import '../../../ui/notice_modal.dart';
import '../../phantom/phantom_screen.dart';

/// "I'm stuck" on a suggested scene: the same prompt taken to a fresh
/// conversation about its chapter, as something to think through with the
/// author — asked not to write the scene, which stays theirs. The desk's
/// `useNextScene.stuck`, word for word.
///
/// Gated as [planChaptersInChat] gates the chat: the room, then the chat's
/// allowance for a fresh conversation on the default model.
Future<void> stuckInChat(BuildContext context, WidgetRef ref, {required String projectId, required NextScene scene}) async {
  final chat = ref.read(capabilityProvider(roomFor(RoomKey.phantom).capability));
  if (!chat.granted) return explainLock(context, chat, roomFor(RoomKey.phantom).title);
  final snapshot = ref.read(quotaProvider).value;
  final quota = chatQuotaFor(snapshot, chatModelRow(ref.read(chatModelsProvider), null));
  if (quota.exhausted) return reportQuotaSpent(quota.feature, snapshot: snapshot);

  final ask = 'I\'m stuck on a scene in “${scene.chapter}”. ${scene.prompt}\n\n'
      "Help me find my way into it: ask me questions and offer a few directions to choose from — but don't write the scene for me.";
  final navigator = Navigator.of(context);
  try {
    final session = await createSession(
      projectId,
      title: scene.headline,
      messages: const [],
      view: ChatView(kind: ChatViewKind.chapter, id: scene.documentId, title: scene.chapter),
    );
    ref.invalidate(chatSessionsProvider(projectId));
    await navigator.pushNamed(PhantomScreen.route, arguments: ChatArrival(sessionId: session.id, ask: ask));
  } catch (e) {
    if (!context.mounted) return;
    await showNoticeModal(
      context,
      eyebrow: 'Apparition',
      title: "Couldn't open the chat.",
      action: 'OK',
      children: [NoticeText('Check your connection and try again. ${messageFor(e)}')],
    );
  }
}
