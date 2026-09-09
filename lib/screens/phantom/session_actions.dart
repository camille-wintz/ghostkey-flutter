import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/providers.dart';
import '../../ds/tokens.dart';
import '../../server/chat/api.dart';
import '../../server/dto/chat.dart';
import '../../server/errors.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import 'delete_chat_dialog.dart';
import 'rename_sheet.dart';

// A session row's long-press: the action sheet, the delete confirmation, and
// the rename card. Rename and delete are plain api calls followed by an
// invalidate; deleting the open conversation also starts a fresh one so the
// thread never shows a row that no longer exists.

enum _Action { rename, delete }

Future<void> showSessionActions(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ChatSessionSummary session,
}) async {
  final action = await showGkSheet<_Action>(
    context,
    header: SheetHeader(eyebrow: session.title, onClose: () => Navigator.of(context).pop()),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionRow(icon: LucideIcons.pencil, label: 'Rename', onPressed: () => Navigator.of(context).pop(_Action.rename)),
        _ActionRow(
          icon: LucideIcons.trash2,
          label: 'Delete',
          destructive: true,
          onPressed: () => Navigator.of(context).pop(_Action.delete),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _Action.rename:
      await _rename(context, ref, projectId: projectId, session: session);
    case _Action.delete:
      await _delete(context, ref, projectId: projectId, session: session);
  }
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ChatSessionSummary session,
}) async {
  final title = await showRenameSheet(context, title: session.title);
  if (title == null || title == session.title) return;
  try {
    await patchSession(projectId, session.id, title: title);
    ref.invalidate(chatSessionsProvider(projectId));
  } catch (e) {
    if (context.mounted) await _failed(context, 'Could not rename chat', e);
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ChatSessionSummary session,
}) async {
  if (!await confirmDeleteChat(context, title: session.title)) return;
  try {
    await deleteSession(projectId, session.id);
    ref.invalidate(chatSessionsProvider(projectId));
    final turn = ref.read(chatTurnProvider(projectId).notifier);
    if (ref.read(chatTurnProvider(projectId)).activeSessionId == session.id) turn.newChat();
  } catch (e) {
    if (context.mounted) await _failed(context, 'Could not delete chat', e);
  }
}

Future<void> _failed(BuildContext context, String title, Object error) => showNoticeModal(
      context,
      eyebrow: 'Something went wrong',
      title: title,
      action: 'OK',
      children: [NoticeText(messageFor(error))],
    );

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onPressed, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ink = destructive ? Ds.destructive : Ds.soft;
    return Press(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, pressed) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: pressed ? Ds.veil : const Color(0x00000000),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 12),
            UiText(label, color: ink),
          ],
        ),
      ),
    );
  }
}
