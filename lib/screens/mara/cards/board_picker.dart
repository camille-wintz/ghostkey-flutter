import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../access/capability.dart';
import '../../../ds/tokens.dart';
import '../../../mara/boards.dart';
import '../../../mara/open_board.dart';
import '../../../mara/providers.dart';
import '../../../server/dto/plan.dart';
import '../../../server/errors.dart';
import '../../../server/providers.dart';
import '../../../ui/lock_notice.dart';
import '../../../ui/page_notice.dart';
import '../../../ui/page_row.dart';
import '../../../ui/room_subtitle.dart';
import '../../../ui/text.dart';
import '../mara_page_frame.dart';

/// The Cards capability — laying beats out on a board.
const String _cardsCapability = 'mara.cards';

/// No board open: the author's boards, by name, then the ways to start one —
/// blank, or on a story structure. A structure already started opens the
/// board that is on it.
class BoardPicker extends ConsumerWidget {
  const BoardPicker({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookTitle = ref.watch(projectProvider(projectId)).value?.project.displayTitle;
    final boards = ref.watch(boardListProvider(projectId));
    final templates = ref.watch(storyTemplatesProvider);
    final writes = ref.watch(boardsProvider(projectId));
    final gate = ref.watch(capabilityProvider(_cardsCapability));
    final list = boards.value ?? const <BoardEntry>[];

    void open(String mapId) => ref.read(openBoardProvider(projectId).notifier).open(mapId);

    Future<void> start({StoryTemplate? template}) async {
      if (writes.busy) return;
      if (!gate.granted) return explainLock(context, gate, 'Cards');
      final started = await ref.read(boardsProvider(projectId).notifier).start(
            template: template,
            name: template == null ? nextBlankBoardName(list.map((b) => b.board.name)) : null,
          );
      if (started != null) open(started.id);
    }

    return MaraPageFrame(
      title: 'Cards',
      subtitle: bookTitle == null ? null : RoomSubtitle(bookTitle),
      child: RefreshIndicator(
        color: Ds.accent,
        backgroundColor: Ds.panel,
        onRefresh: () => ref.refresh(storyMapsProvider(projectId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 40),
          children: [
            if (writes.error case final error?)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: PageNotice(error, error: true)),
            if (boards.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PageNotice("Your boards wouldn't load: ${messageFor(boards.error)}", error: true),
              ),
            if (list.isNotEmpty) ...[
              const _Heading('Your boards'),
              for (final entry in list)
                PageRow(
                  icon: entry.structure == null ? LucideIcons.squareDashed : LucideIcons.layoutDashboard,
                  label: entry.title,
                  description: entry.structure ?? 'No structure',
                  onOpen: () => open(entry.board.id),
                ),
              const SizedBox(height: 18),
            ],
            const _Heading('Start a board'),
            if (writes.busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            PageRow(
              icon: LucideIcons.squareDashed,
              label: 'Blank board',
              description: 'An empty board in your own shape — no beats to answer',
              onOpen: () => start(),
            ),
            ...switch (templates) {
              AsyncData(:final value) => [
                  for (final template in value)
                    PageRow(
                      icon: LucideIcons.layoutDashboard,
                      label: template.name,
                      description: template.description,
                      trailingLabel: _startedOn(list, template) == null ? null : 'Open',
                      onOpen: () => switch (_startedOn(list, template)) {
                        final started? => open(started.id),
                        null => start(template: template),
                      },
                    ),
                ],
              AsyncError(:final error) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: PageNotice("The story structures wouldn't load: ${messageFor(error)}", error: true),
                  ),
                ],
              _ => [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiText('Loading the story structures…', step: DsText.ui, color: Ds.low),
                  ),
                ],
            },
          ],
        ),
      ),
    );
  }

  static StoryMap? _startedOn(List<BoardEntry> boards, StoryTemplate template) =>
      boards.where((b) => b.board.templateId == template.id).firstOrNull?.board;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Eyebrow(text),
      );
}
