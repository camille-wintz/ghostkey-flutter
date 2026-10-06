import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/review/providers.dart';
import '../server/jobs/api.dart';
import 'providers.dart';

/// The capability a line edit is gated on — the desk's, whichever room starts it.
const String lineEditCapability = 'apparition.line_edit';

/// Start a line edit on one chapter: the same `edit_pass` job Apparition's
/// panel and the chat start, so a pass started here shows everywhere. The
/// model is the server's default, and there is no brief: the focus field went
/// with the desk's on 2026-10-06 (crutches on the style sheet took its place
/// there). Throws what the server refused with.
Future<void> startLineEdit(WidgetRef ref, String projectId, String documentId) async {
  await startJob(projectId, 'edit_pass', params: {
    'subject': documentId,
    'depth': 'line_edit',
  });
  ref.invalidate(wispJobsProvider(projectId));
  ref.invalidate(editPassJobProvider((projectId: projectId, subject: documentId)));
}
