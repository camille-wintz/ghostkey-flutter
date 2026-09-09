import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../editor/capture_launchers.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/state_screen.dart';
import '../project/project_root.dart';
import 'chapter_editor.dart';
import 'document_resolve.dart';

/// The page behind the drawer: resolves the active chapter's filename to a
/// document and mounts [ChapterEditor] for it, keyed by document id — so a
/// title rename doesn't wipe the editor, and a chapter switch is one editor
/// going (flushing) and the next arriving.
class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key, required this.rename, this.onDictate, this.onScan});

  final RecentRename rename;
  final CaptureLauncher? onDictate;
  final CaptureLauncher? onScan;

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  bool _openedForEmpty = false;

  void _openDrawer() => Scaffold.of(context).openDrawer();

  /// Open the chapter drawer when no chapter is selected — once per time
  /// the selection goes empty, not on every build.
  void _autoOpen(bool empty) {
    if (!empty) {
      _openedForEmpty = false;
      return;
    }
    if (_openedForEmpty) return;
    _openedForEmpty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDrawer();
    });
  }

  void _onRenamed(String documentId, String filename) {
    widget.rename.note(documentId, filename);
    ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
    ref.invalidate(projectProvider(ProjectScope.of(context)));
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ProjectScope.of(context);
    final filename = ref.watch(activeProjectProvider.select((p) => p.activeChapter));
    final project = ref.watch(projectProvider(projectId));
    final data = project.value;

    _autoOpen(filename == null);

    if (filename == null) {
      return StateScreen(
        icon: LucideIcons.bookOpen,
        message: 'Select a chapter from the side menu.',
        actionLabel: 'Open chapter list',
        onAction: _openDrawer,
      );
    }
    if (data == null) {
      return project.hasError
          ? StateScreen(message: messageFor(project.error))
          : const StateScreen(spinner: true, message: 'Loading chapter…');
    }
    final documentId = resolveDocumentId(data, filename, widget.rename);
    if (documentId == null) return StateScreen(message: 'Chapter "$filename" not found.');

    return ChapterEditor(
      key: ValueKey(documentId),
      projectId: projectId,
      documentId: documentId,
      filename: filename,
      typography: data.project.typography,
      onRenamed: (next) => _onRenamed(documentId, next),
      openDrawer: _openDrawer,
      onDictate: widget.onDictate,
      onScan: widget.onScan,
    );
  }
}
