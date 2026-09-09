import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../server/bible/api.dart';
import '../../server/dossiers/api.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/projects.dart';
import '../../server/projects/api.dart';

// The room's own server reads. All autoDispose: a chapter's content, the
// bible and the dossier map are dropped when nothing is looking at them, so a
// hundred opened chapters are not a hundred chapters held in memory.

typedef DocumentKey = ({String projectId, String documentId});

/// One document's server copy. The editor reads it ONCE, on open; it never
/// re-reads it under the author's typing (a refetch that rolled the editor
/// back inside the autosave window is a bug this app has had before).
final documentProvider = FutureProvider.autoDispose.family<DocumentDto, DocumentKey>(
  (ref, key) => getDocument(key.projectId, key.documentId),
);

/// The series' world bible as this book sees it: the chapter's cast reads it.
final bibleProvider = FutureProvider.autoDispose.family<BibleResponse, String>(
  (ref, projectId) => getBible(projectId),
);

/// Every cached dossier for the project, keyed by entity key. A key that is
/// absent has never been built — the read never generates anything.
final dossiersProvider = FutureProvider.autoDispose.family<Map<String, Dossier>, String>(
  (ref, projectId) => getDossiers(projectId),
);
