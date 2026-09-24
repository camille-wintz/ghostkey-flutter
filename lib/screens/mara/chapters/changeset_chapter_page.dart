import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/providers.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/state_screen.dart';
import '../mara_page_frame.dart';
import 'changeset_chapter_fields.dart';

/// The chapters one change writes, full screen: their titles and notes, the
/// author's to reword before the changes are applied, and the change's skip.
/// [index] narrows it to one chapter of an add.
class ChangesetChapterPage extends ConsumerWidget {
  const ChangesetChapterPage({super.key, required this.projectId, required this.opId, this.index});
  final String projectId;
  final String opId;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref
        .watch(authoredOutlineProvider(projectId))
        .value
        ?.changeset
        ?.ops
        .whereType<ChangesetWrite>()
        .where((o) => o.id == opId)
        .firstOrNull;
    return MaraPageFrame(
      title: switch (op) {
        ChangesetAdd() => 'New chapter',
        ChangesetRewrite() => 'Rewritten',
        null => 'Change',
      },
      child: op == null
          ? const StateScreen(message: 'This change is no longer proposed')
          : ChangesetChapterFields(key: ValueKey('$opId-$index'), projectId: projectId, op: op, index: index),
    );
  }
}
