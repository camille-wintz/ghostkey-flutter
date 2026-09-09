import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/models.dart';
import '../../chat/providers.dart';
import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../server/providers.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import '../project/drawer_head.dart';
import 'session_actions.dart';
import 'session_row.dart';

/// The room's sidebar as drawer content: the book's name as the way back to
/// the project home, new chat, the saved sessions newest first (long-press to
/// rename or delete), and the weekly quota line.
///
/// The head is Apparition's — the same [DrawerHead] the chapter drawer wears.
/// The way out used to be a faint link under the quota at the foot of the
/// list, which is the same door in a place no one would look for it twice.
class ChatSessionsDrawer extends ConsumerWidget {
  const ChatSessionsDrawer({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(chatSessionsProvider(projectId));
    final activeId = ref.watch(chatTurnProvider(projectId).select((s) => s.activeSessionId));
    final quota = quotaLine(ref.watch(quotaProvider).value?.feature(chatQuotaFeature));
    final turn = ref.read(chatTurnProvider(projectId).notifier);
    final title = ref.watch(projectProvider(projectId)).value?.project.displayTitle ?? 'Project';
    final count = sessions.value?.length;

    void close() => Scaffold.of(context).closeDrawer();

    return ColoredBox(
      color: Ds.panel,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHead(
              title: title,
              meta: count == null ? null : '$count ${count == 1 ? 'chat' : 'chats'}',
              // An open drawer holds a local-history entry on the room's
              // route, and a pop with one present only closes the drawer.
              // Closing it first drops the entry (on the reverse status,
              // synchronously), so the pop that follows leaves the room.
              onLeave: () {
                final nav = Navigator.of(context);
                close();
                nav.pop();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 6),
              child: Press(
                onPressed: () {
                  turn.newChat();
                  close();
                },
                semanticLabel: 'New chat',
                builder: (context, pressed) => AnimatedContainer(
                  duration: DsMotion.duration,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: pressed ? Ds.accentMix(12) : Ds.surf,
                    border: Border.all(color: Ds.edge),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.plus, size: 18, color: Ds.accent),
                      const SizedBox(width: 8),
                      UiText('New chat', step: DsText.ui, color: Ds.soft, weight: FontWeight.w600),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (sessions) {
                AsyncValue(value: final list?) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: UiText('No saved chats yet.', step: DsText.ui, color: Ds.mid),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        itemCount: list.length,
                        itemBuilder: (context, i) => SessionRow(
                          key: ValueKey(list[i].id),
                          session: list[i],
                          active: list[i].id == activeId,
                          onPressed: () {
                            turn.selectSession(list[i].id);
                            close();
                          },
                          onLongPress: () => showSessionActions(context, ref, projectId: projectId, session: list[i]),
                        ),
                      ),
                AsyncValue(hasError: true) => Padding(
                    padding: const EdgeInsets.all(14),
                    child: UiText('Could not load your chats.', step: DsText.ui, color: Ds.mid),
                  ),
                _ => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
                      ),
                    ),
                  ),
              },
            ),
            if (quota != null)
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
                alignment: Alignment.centerLeft,
                child: UiText(quota, step: DsText.eyebrow, color: Ds.faint),
              ),
          ],
        ),
      ),
    );
  }
}
