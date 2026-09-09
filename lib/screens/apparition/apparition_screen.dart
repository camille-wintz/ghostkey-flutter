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
import 'drawer/chapter_drawer.dart';
import 'drawer/chapter_drawer_state.dart';

/// The writing room: the chapter editor behind a chapters/notes drawer.
/// `activeChapter` belongs here and nowhere else.
///
/// The room is built AFTER the push lands, not during it (`Entered`). What
/// mounts here is a drawer, and an editor holding a whole chapter in one
/// field — that in the frames the entry animation needs is what made
/// opening Apparition feel like the app had stopped rather than moved.
///
/// What the drawer remembers between opens (its query, its folded folders,
/// an order that has not landed) lives here, above it: Flutter's drawer
/// holds no content while closed.
class ApparitionScreen extends ConsumerStatefulWidget {
  const ApparitionScreen({super.key});
  static const route = '/apparition';

  @override
  ConsumerState<ApparitionScreen> createState() => _ApparitionScreenState();
}

class _ApparitionScreenState extends ConsumerState<ApparitionScreen> {
  ChapterDrawerState? _drawer;
  final RecentRename _rename = RecentRename();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = ProjectScope.of(context);
    _drawer ??= ChapterDrawerState(
      projectId: projectId,
      refreshProject: () => ref.invalidate(projectProvider(projectId)),
    );
  }

  @override
  void dispose() {
    _drawer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.apparition),
        builder: (context) => Scaffold(
          backgroundColor: Ds.void_,
          // 318 of the design's 390pt frame — the page stays visible beside it.
          drawer: Drawer(
            width: MediaQuery.sizeOf(context).width * 0.82,
            backgroundColor: Ds.panel,
            elevation: 0,
            shape: const RoundedRectangleBorder(),
            child: ChapterDrawer(state: _drawer!, rename: _rename),
          ),
          drawerEdgeDragWidth: 60,
          drawerScrimColor: const Color(0x8C000000),
          body: ChapterScreen(rename: _rename, onDictate: CaptureLaunchers.dictate, onScan: CaptureLaunchers.scan),
        ),
      );
}
