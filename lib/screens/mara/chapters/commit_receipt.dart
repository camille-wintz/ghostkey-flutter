import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../rooms/rooms.dart';
import '../../../ui/button.dart';
import '../../project/project_root.dart';

/// What a commit made, said once over the book it made, with the way to start
/// writing it.
class CommitReceiptBanner extends ConsumerWidget {
  const CommitReceiptBanner({super.key, required this.projectId, required this.receipt});
  final String projectId;
  final CommitReceipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = receipt.firstFilename;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(Ds.panel, Ds.done, 0.08),
        border: Border.all(color: Ds.done.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${receipt.count} ${receipt.count == 1 ? 'chapter' : 'chapters'} created in “${receipt.draftName}”',
            style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text("They're the book now — each one's notes are below.", style: DsStyle.ui(DsText.ui, color: Ds.mid)),
          if (first != null) ...[
            const SizedBox(height: 12),
            GkButton(
              label: 'Open chapter one',
              onPressed: () {
                ref.read(chapterPlanWritesProvider(projectId).notifier).forgetCommit();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  routeForRoom(RoomKey.apparition),
                  (route) => route.isFirst,
                  arguments: first,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
