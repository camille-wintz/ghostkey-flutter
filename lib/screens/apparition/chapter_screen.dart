import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../editor/capture_launchers.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/anchored_panel.dart';
import '../../ui/state_screen.dart';
import '../project/project_root.dart';
import 'chapter_editor.dart';
import 'document_resolve.dart';
import 'nav/chapter_nav.dart';
import 'nav/chapter_nav_state.dart';

/// The page under the chapter list: resolves the active chapter's filename to
/// a document and mounts [ChapterEditor] for it, keyed by document id — so a
/// title rename doesn't wipe the editor, and a chapter switch is one editor
/// going (flushing) and the next arriving.
///
/// It also owns the list, because it is what opens it: from the title's own
/// chevron while a chapter is open, and from the middle of the screen while
/// none is.
class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key, required this.nav, required this.rename, this.onDictate, this.onScan});

  final ChapterNavState nav;
  final RecentRename rename;
  final CaptureLauncher? onDictate;
  final CaptureLauncher? onScan;

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  bool _openedForEmpty = false;

  /// The list is a route, so a second open would stack a second panel on the
  /// first — which is what deleting the chapter you are in does, since that
  /// empties the selection while the list that deleted it is still up.
  bool _navOpen = false;

  void _openNav([Rect? anchor]) {
    if (_navOpen) return;
    _navOpen = true;
    unawaited(
      showAnchoredPanel<void>(
        context,
        anchor: anchor,
        label: 'Chapters',
        builder: (context) => ChapterNav(state: widget.nav, rename: widget.rename),
      ).whenComplete(() => _navOpen = false),
    );
  }

  /// Open the chapter list when no chapter is selected — once per time the
  /// selection goes empty, not on every build.
  void _autoOpen(bool empty) {
    if (!empty) {
      _openedForEmpty = false;
      return;
    }
    if (_openedForEmpty) return;
    _openedForEmpty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openNav();
    });
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
        message: 'Pick a chapter to start writing.',
        actionLabel: 'Open chapter list',
        onAction: _openNav,
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
      onBack: () => Navigator.of(context).pop(),
      onOpenChapters: _openNav,
      onDictate: widget.onDictate,
      onScan: widget.onScan,
    );
  }
}
