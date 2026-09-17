import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/review/providers.dart';
import '../server/jobs/api.dart';
import 'providers.dart';

/// The capability a line edit is gated on — the desk's, whichever room starts it.
const String lineEditCapability = 'apparition.line_edit';

/// Start a line edit on one chapter: the same `edit_pass` job Apparition's
/// panel and the chat start, so a pass started here shows everywhere. The
/// model is the server's default; the brief is the author's focus, if any.
/// Throws what the server refused with.
Future<void> startLineEdit(WidgetRef ref, String projectId, String documentId, String instructions) async {
  await startJob(projectId, 'edit_pass', params: {
    'subject': documentId,
    'depth': 'line_edit',
    if (instructions.trim().isNotEmpty) 'instructions': instructions.trim(),
  });
  ref.invalidate(wispJobsProvider(projectId));
  ref.invalidate(editPassJobProvider((projectId: projectId, subject: documentId)));
}
