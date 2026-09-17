import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/review/providers.dart';
import '../../../ds/tokens.dart';
import '../../../server/dto/jobs.dart';
import '../../../server/jobs/api.dart';
import '../../../ui/button.dart';
import '../pulse.dart';

/// Under a subject with no notes to review: a pass still running, or one that
/// failed. Nothing at all when there is no pass.
class PassStatus extends ConsumerWidget {
  const PassStatus({super.key, required this.subject, required this.job});
  final SubjectKey subject;
  final AsyncValue<JobSnapshot?> job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = job.value;
    if (row == null || row.status == JobStatus.done || row.status == JobStatus.cancelled) {
      return const SizedBox.shrink();
    }
    final running = row.isRunning;
    final label = running
        ? (row.progress?.label.isNotEmpty ?? false ? row.progress!.label : 'Line editing…')
        : (row.errorDetail ?? 'The line edit did not finish.');

    return DecoratedBox(
      decoration: BoxDecoration(color: Ds.panel, border: Border(top: BorderSide(color: Ds.edge))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Pulse(
                  active: running,
                  child: Text(label, style: DsStyle.ui(DsText.ui, color: running ? Ds.soft : Ds.destructive)),
                ),
              ),
              if (!running)
                GkButton(
                  label: 'Dismiss',
                  variant: ButtonVariant.outline,
                  onPressed: () async {
                    await dismissJob(subject.projectId, row.id).catchError((_) {});
                    ref.invalidate(editPassJobProvider(subject));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
