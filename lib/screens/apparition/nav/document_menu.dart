import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../server/dto/projects.dart';
import '../../../server/errors.dart';
import '../../../store/active_project.dart';
import '../document_resolve.dart';
import '../room_alert.dart';
import 'chapter_nav_state.dart';
import 'row_sheets.dart';

/// A document's menu — rename it or delete it — and what follows either.
///
/// One owner for both doors to it: a held row in the chapter list, and the
/// corner of the open chapter's title block. Renaming the chapter you are in
/// moves the active filename with it; deleting it empties the selection, which
/// is what brings the list back up.
Future<void> showDocumentMenu(
  BuildContext context,
  WidgetRef ref, {
  required ChapterNavState state,
  required RecentRename recent,
  required ProjectFull data,
  required DocumentSummary doc,
}) async {
  final isNote = data.notes.any((n) => n.id == doc.id);
  final action = await showRowMenu(context, label: doc.label);
  if (!context.mounted || action == null) return;

  Future<void> guard(Future<void> Function() write, String title) async {
    try {
      await write();
    } catch (e) {
      if (context.mounted) unawaited(showRoomAlert(context, title: title, message: messageFor(e)));
    }
  }

  final active = ref.read(activeProjectProvider).activeChapter;
  switch (action) {
    case RowAction.rename:
      final title = await showRenameSheet(context, current: doc.label);
      if (!context.mounted || title == null) return;
      await guard(() async {
        final filename = await state.rename(doc, title);
        if (doc.filename == active) {
          recent.note(doc.id, filename);
          ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
        }
      }, 'Rename failed');
    case RowAction.delete:
      if (!await confirmDelete(context, label: doc.label) || !context.mounted) return;
      await guard(() async {
        await (isNote ? state.deleteNote(data, doc) : state.deleteChapter(data, doc));
        if (doc.filename == active) ref.read(activeProjectProvider.notifier).setActiveChapter(null);
      }, 'Could not delete');
  }
}
