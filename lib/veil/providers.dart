import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/bible/api.dart';
import '../server/config.dart';
import '../server/dossiers/api.dart';
import '../server/dto/bible.dart';

// Veil's two server reads. Both are keyed by project — the desktop learnt
// that a bare key showed book 1's cast on book 2 — and both drop when the
// room is left (`autoDispose`), so reopening the room is what picks up a
// second device's edits. Neither self-refetches: a run invalidates them.

final bibleProvider = FutureProvider.autoDispose.family<BibleResponse, String>(
  (ref, projectId) => getBible(projectId),
);

/// Every dossier the server has cached for this book, keyed by entity key.
/// A key that is absent has never been built — the difference the entity
/// page needs before it pays for one.
final dossiersProvider = FutureProvider.autoDispose.family<Map<String, Dossier>, String>(
  (ref, projectId) => getDossiers(projectId),
);

/// A SERIES asset's URL, or null when there is nothing to draw. No auth
/// header: the route answers on the strength of the id, which is what lets
/// the image cache work. Series-scoped because the project asset route
/// filters on project_id and 404s for a sibling book's portrait.
String? seriesAssetUrl(String? seriesId, String? assetId) {
  if (seriesId == null || seriesId.isEmpty || assetId == null || assetId.isEmpty) return null;
  return '$serverBaseUrl/api/series/$seriesId/assets/$assetId';
}
