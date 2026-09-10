import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../editor/capture_launchers.dart';
import '../../rooms/rooms.dart';
import '../../server/providers.dart';
import '../project/project_root.dart';
import '../project/room_entering.dart';
import 'chapter_screen.dart';
import 'document_resolve.dart';
import 'nav/chapter_nav_state.dart';

/// The writing room: the chapter editor, with the chapters/notes list one
/// press of the title away. `activeChapter` belongs here and nowhere else.
///
/// The room is built AFTER the push lands, not during it (`Entered`). What
/// mounts here is an editor holding a whole chapter in one field — that in the
/// frames the entry animation needs is what made opening Apparition feel like
/// the app had stopped rather than moved.
///
/// What the list remembers between opens (its query, its folded folders, an
/// order that has not landed) lives here, above it: the panel is a route that
/// is gone the moment it closes.
class ApparitionScreen extends ConsumerStatefulWidget {
  const ApparitionScreen({super.key});
  static const route = '/apparition';

  @override
  ConsumerState<ApparitionScreen> createState() => _ApparitionScreenState();
}

class _ApparitionScreenState extends ConsumerState<ApparitionScreen> {
  ChapterNavState? _nav;
  final RecentRename _rename = RecentRename();

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

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.apparition),
        builder: (context) => Scaffold(
          backgroundColor: Ds.void_,
          body: ChapterScreen(
            nav: _nav!,
            rename: _rename,
            onDictate: CaptureLaunchers.dictate,
            onScan: CaptureLaunchers.scan,
          ),
        ),
      );
}
