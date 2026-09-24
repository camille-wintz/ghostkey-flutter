import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/open_board.dart';
import '../../../mara/providers.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import '../../project/project_root.dart';
import '../mara_page_frame.dart';
import 'board_picker.dart';
import 'board_screen.dart';

/// Cards: the board the author was on in this book, or the picker when there
/// is none — or the one remembered has gone since (deleted elsewhere), which
/// is only known once the list is in.
class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final open = ref.watch(openBoardProvider(projectId));
    final maps = ref.watch(storyMapsProvider(projectId));
    if (!open.hasValue) {
      return const MaraPageFrame(title: 'Cards', child: StateScreen(spinner: true, message: 'Opening Cards…'));
    }
    final id = open.value;
    if (id == null) return BoardPicker(projectId: projectId);
    final board = maps.value?.where((m) => m.authored && m.id == id).firstOrNull;
    if (board != null) return BoardScreen(projectId: projectId, board: board);
    if (maps.hasValue) return BoardPicker(projectId: projectId);
    if (maps.hasError) {
      return MaraPageFrame(
        title: 'Cards',
        child: StateScreen(
          message: 'The board would not open',
          detail: messageFor(maps.error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(storyMapsProvider(projectId)),
        ),
      );
    }
    return const MaraPageFrame(title: 'Cards', child: StateScreen(spinner: true, message: 'Opening the board…'));
  }
}
