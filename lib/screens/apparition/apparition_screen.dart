import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../editor/capture_launchers.dart';
import '../../next_scene/next_scene_finder.dart';
import '../../rewards/providers.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/next_scene.dart';
import '../../server/dto/projects.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../project/project_root.dart';
import '../project/room_entering.dart';
import 'chapter_screen.dart';
import 'document_resolve.dart';
import 'home/apparition_home.dart';
import 'nav/chapter_nav.dart';
import 'nav/chapter_nav_state.dart';
import 'next_scene/stuck_in_chat.dart';

/// The writing room: its home (where you left off, the words, the manuscript,
/// the latest cat — `ApparitionHome`) over the book's chapters and notes as
/// one page, and each document opening as a page pushed on top (Cleo, 2026-09-24 — the list used
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
  NextSceneFinder? _finder;
  final RecentRename _rename = RecentRename();
  bool _openingChat = false;

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
    _finder ??= NextSceneFinder(projectId: projectId);
  }

  @override
  void dispose() {
    _nav?.dispose();
    _finder?.dispose();
    super.dispose();
  }

  Future<void> _open(String filename, {bool atEnd = false}) async {
    if (!mounted) return;
    ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterScreen(
          nav: _nav!,
          rename: _rename,
          onDictate: CaptureLaunchers.dictate,
          onScan: CaptureLaunchers.scan,
          finder: _finder,
          revealEnd: atEnd,
        ),
      ),
    );
    // The home stood under the chapter the whole time: what was written
    // there is the words, the streak, perhaps a cat, and where you left off.
    if (!mounted) return;
    ref.invalidate(rewardsProvider);
    ref.invalidate(catsProvider);
    ref.invalidate(projectProvider(ProjectScope.of(context)));
  }

  /// "Let's write": the scene's chapter, at its end, with the prompt over it.
  void _write(NextScene scene) {
    final data = ref.read(projectProvider(ProjectScope.of(context))).value;
    final doc = data == null ? null : chaptersInTree(data.chapters).where((d) => d.id == scene.documentId).firstOrNull;
    if (doc == null) {
      // A chapter the list hasn't caught up with: the next read has it.
      ref.invalidate(projectProvider(ProjectScope.of(context)));
      return;
    }
    _finder!.takeBrief(scene);
    _open(doc.filename, atEnd: true);
  }

  Future<void> _stuck(NextScene scene) async {
    setState(() => _openingChat = true);
    await stuckInChat(context, ref, projectId: ProjectScope.of(context), scene: scene);
    if (mounted) setState(() => _openingChat = false);
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
              head: ApparitionHome(
                finder: _finder!,
                onOpen: _open,
                onWrite: _write,
                onStuck: _stuck,
                stuckPending: _openingChat,
              ),
            ),
          ),
        ),
      );
}
