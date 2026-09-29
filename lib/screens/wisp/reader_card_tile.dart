import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/job_running.dart';
import '../../ui/lock_notice.dart';
import '../../wisp/access.dart';
import '../../wisp/wisp_run.dart';
import 'beta_read_start.dart';
import 'reader_portrait.dart';
import 'report_card.dart';

/// One beta reader on the page: who they are and what they like, then their
/// state — asking them to read, their read in progress, or their letter.
class ReaderCardTile extends ConsumerWidget {
  const ReaderCardTile({
    super.key,
    required this.projectId,
    required this.reader,
    required this.onOpen,
    this.disabled = false,
  });
  final String projectId;
  final ReaderCard reader;
  final VoidCallback onOpen;

  /// The book can't be read yet (too short, or still loading).
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runKey = analysisRunKey(projectId, reader.analysis);
    final run = ref.watch(wispRunProvider(runKey));
    final gate = ref.watch(capabilityProvider(analysisCapability));

    // The list stays mounted under an open letter, so a refused run is
    // answered here once, whichever screen started it.
    ref.listen(wispRunProvider(runKey), (prev, next) {
      if (next.denial case final denial? when prev?.denial == null) {
        ref.invalidate(accessProvider);
        explainDenial(context, denial, fullReportsLabel);
      }
    });

    final Widget state;
    if (run.running) {
      state = Row(
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              jobProgressLine(run.progress, '${reader.name} is reading'),
              style: DsStyle.ui(DsText.ui, color: Ds.accent300),
            ),
          ),
        ],
      );
    } else if (reader.hasLetter) {
      state = GkButton(
        label: 'Read the letter',
        onPressed: onOpen,
        leading: Icon(LucideIcons.mailOpen, size: 14, color: Ds.accent),
      );
    } else {
      state = GkButton(
        label: 'Ask ${reader.name} to read',
        variant: ButtonVariant.outline,
        onPressed: () => startBetaRead(context, ref, projectId, reader, again: false),
        disabled: disabled,
        leading: Icon(gate.granted ? LucideIcons.bookOpen : LucideIcons.lock, size: 14, color: Ds.mid),
      );
    }

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReaderPortrait(reader: reader),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reader.name, style: DsStyle.prose(const DsStep(22, 28), color: Ds.hi)),
                    if (reader.genres.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(reader.genres, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (reader.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(reader.description, style: DsStyle.prose(DsText.body, color: Ds.soft)),
          ],
          const SizedBox(height: 16),
          state,
          if (run.error case final error? when !run.running && run.denial == null) ...[
            const SizedBox(height: 10),
            Text(error, style: DsStyle.ui(DsText.ui, color: Ds.destructive)),
          ],
        ],
      ),
    );
  }
}
