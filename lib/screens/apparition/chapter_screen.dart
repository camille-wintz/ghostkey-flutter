import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../editor/capture_launchers.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/state_screen.dart';
import '../project/project_root.dart';
import 'chapter_editor.dart';
import 'document_resolve.dart';
import 'nav/chapter_nav_state.dart';
import 'nav/document_menu.dart';

/// One document as a page, pushed over the chapter list: resolves the active
/// chapter's filename to a document and mounts [ChapterEditor] for it, keyed
/// by document id — so a title rename doesn't wipe the editor. Leaving is a
/// pop, which is the editor going (flushing).
///
/// Deleting the open document from its own menu empties the selection, and
/// the page goes back to the list with it.
class ChapterScreen extends ConsumerWidget {
  const ChapterScreen({super.key, required this.nav, required this.rename, this.onDictate, this.onScan});

  final ChapterNavState nav;
  final RecentRename rename;
  final CaptureLauncher? onDictate;
  final CaptureLauncher? onScan;

  /// The open chapter's own menu. Read fresh on press: the tree the page
  /// last built from may already be behind a rename.
  void _openMenu(BuildContext context, WidgetRef ref, String documentId) {
    final data = ref.read(projectProvider(ProjectScope.of(context))).value;
    if (data == null) return;
    final doc = [...chaptersInTree(data.chapters), ...data.notes].where((d) => d.id == documentId).firstOrNull;
    if (doc == null) return;
    unawaited(showDocumentMenu(context, ref, state: nav, recent: rename, data: data, doc: doc));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final filename = ref.watch(activeProjectProvider.select((p) => p.activeChapter));
    final project = ref.watch(projectProvider(projectId));
    final data = project.value;
    void back() => Navigator.of(context).maybePop();

    ref.listen(activeProjectProvider.select((p) => p.activeChapter), (_, next) {
      if (next == null) back();
    });

    return Scaffold(
      backgroundColor: Ds.void_,
      body: Builder(
        builder: (context) {
          if (filename == null) return const SizedBox.shrink();
          if (data == null) {
            return project.hasError
                ? StateScreen(message: messageFor(project.error), actionLabel: 'Back to the chapters', onAction: back)
                : const StateScreen(spinner: true, message: 'Loading chapter…');
          }
          final documentId = resolveDocumentId(data, filename, rename);
          if (documentId == null) {
            return StateScreen(
              message: "That chapter isn't in this book any more.",
              actionLabel: 'Back to the chapters',
              onAction: back,
            );
          }
          return ChapterEditor(
            key: ValueKey(documentId),
            projectId: projectId,
            documentId: documentId,
            filename: filename,
            typography: data.project.typography,
            onBack: back,
            onMenu: () => _openMenu(context, ref, documentId),
            onDictate: onDictate,
            onScan: onScan,
          );
        },
      ),
    );
  }
}
