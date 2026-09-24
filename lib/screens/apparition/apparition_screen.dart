import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../editor/capture_launchers.dart';
import '../../rooms/rooms.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../project/project_root.dart';
import '../project/room_entering.dart';
import 'chapter_screen.dart';
import 'document_resolve.dart';
import 'nav/chapter_nav.dart';
import 'nav/chapter_nav_state.dart';

/// The writing room: the book's chapters and notes as a page, and each
/// document opening as a page pushed on top (Cleo, 2026-09-24 — the list used
/// to be a panel unfolded from the open chapter's title). `activeChapter`
/// belongs here and nowhere else: it is the document that is open, or was last
/// open, which the list marks and scrolls to.
///
/// The room is built AFTER the push lands, not during it (`Entered`).
///
/// What the list remembers while the room is up (its query, its folded
/// folders, an order that has not landed) lives here, so a chapter opened and
/// closed comes back to the list as it was left.
class ApparitionScreen extends ConsumerStatefulWidget {
  const ApparitionScreen({super.key, this.open});
  static const route = '/apparition';

  /// A document to open straight away, by filename — for a door elsewhere that
  /// leads into one chapter (Mara's "Open chapter one"). Back from it is the
  /// list, as it is for a chapter opened from there.
  final String? open;

  @override
  ConsumerState<ApparitionScreen> createState() => _ApparitionScreenState();
}

class _ApparitionScreenState extends ConsumerState<ApparitionScreen> {
  ChapterNavState? _nav;
  final RecentRename _rename = RecentRename();

  @override
  void initState() {
    super.initState();
    final open = widget.open;
    if (open != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(open));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = ProjectScope.of(context);
    _nav ??= ChapterNavState(
      projectId: projectId,
      refreshProject: () => ref.invalidate(projectProvider(projectId)),
    );
  }

  @override
  void dispose() {
    _nav?.dispose();
    super.dispose();
  }

  void _open(String filename) {
    if (!mounted) return;
    ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterScreen(
          nav: _nav!,
          rename: _rename,
          onDictate: CaptureLaunchers.dictate,
          onScan: CaptureLaunchers.scan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.apparition),
        builder: (context) => Scaffold(
          backgroundColor: Ds.void_,
          body: SafeArea(
            bottom: false,
            child: ChapterNav(
              state: _nav!,
              rename: _rename,
              onBack: () => Navigator.of(context).pop(),
              onOpen: _open,
            ),
          ),
        ),
      );
}
