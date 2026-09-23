import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import 'billing/api.dart';
import 'dto/billing.dart';
import 'dto/models.dart';
import 'dto/gift.dart';
import 'dto/projects.dart';
import 'folders/api.dart';
import 'gift/api.dart';
import 'models/api.dart';
import 'projects/api.dart';
import 'series/api.dart';

// Every server read the shelf, the account and the project home make, as
// providers — the React Query cache entries of the RN app. A mutation is a
// plain call to the api followed by `ref.invalidate(...)` of what it moved.
//
// Nothing here is gated on sign-in by a flag: a read while signed out has no
// caller, and the whole cache is dropped on sign-out (`clearServerCache`).

final projectsProvider = FutureProvider.family<List<ProjectMeta>, String?>(
  (ref, folderId) => listProjects(folderId),
);

final projectProvider = FutureProvider.family<ProjectFull, String>(
  (ref, id) => getProject(id),
);

final projectWordCountProvider = FutureProvider.family<int, String>(
  (ref, id) => getProjectWordCount(id),
);

/// The open project's plan, or null when the writer has never opened the
/// board. The chapter list's dots read it, and so does Poltergeist.
final projectPlanProvider = FutureProvider.family<ProjectPlan?, String>(
  (ref, id) => getProjectPlan(id),
);

final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  final folders = await listFolders();
  return folders..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Series by id, for the shelf's third line. A stale name costs a caption.
final seriesByIdProvider = FutureProvider<Map<String, Series>>((ref) async {
  final series = await listSeries();
  return {for (final s in series) s.id: s};
});

/// The name to print under a book, or null for an unnamed (implicit) series
/// and for one that has not loaded — both mean "draw a bare book".
String? seriesLabel(Map<String, Series>? series, String seriesId) {
  final found = series?[seriesId];
  if (found == null || found.implicit) return null;
  return found.name;
}

final subscriptionProvider = FutureProvider<SubscriptionSnapshot>((ref) => getSubscription());

/// The plan-access table. `capabilityFrom` reads an absent snapshot as
/// "granted", so a room never locks because a fetch was slow.
final accessProvider = FutureProvider<AccessSnapshot>((ref) => getAccess());

final quotaProvider = FutureProvider<QuotaSnapshot>((ref) => getQuota());

final planCatalogProvider = FutureProvider<PlanCatalog>((ref) => getPlanCatalog());

/// The model pickers (GET /api/models). The same for every account, so it
/// survives sign-out like the plan catalog. No fallback list: until it lands
/// the chat picker offers nothing and a turn sends no model.
final modelCatalogProvider = FutureProvider<ModelCatalog>((ref) => getModelCatalog());

/// Both sides of the account's gift — the free Basic it can give once it
/// pays, and the one it holds. The first read after paying mints the code.
final giftProvider = FutureProvider.autoDispose<GiftRead>((ref) => getMyGift());

/// Drop every server read. Called on sign-out, so the next account on this
/// phone never sees the last one's shelf for a frame.
void clearServerCache(WidgetRef ref) {
  ref.invalidate(projectsProvider);
  ref.invalidate(projectProvider);
  ref.invalidate(projectWordCountProvider);
  ref.invalidate(projectPlanProvider);
  ref.invalidate(foldersProvider);
  ref.invalidate(seriesByIdProvider);
  ref.invalidate(subscriptionProvider);
  ref.invalidate(accessProvider);
  ref.invalidate(quotaProvider);
  ref.invalidate(giftProvider);
}

/// The signed-in gate every read above assumes. Watch it where a screen can
/// be built during the sign-out frame.
final serverReadyProvider = Provider<bool>((ref) => ref.watch(signedInProvider));
