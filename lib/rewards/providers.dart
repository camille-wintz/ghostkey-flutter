import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/rewards.dart';
import '../server/rewards/api.dart';

// The ledger and the cat shelf as Apparition's home reads them. Per account,
// not per book: a day's writing is every book's words added up, and so is
// the target it is measured against. All auto-dispose, so coming back to the
// home reads fresh.

/// The whole ledger over the last [days] local days: the daily writing across
/// every live book, the ticked days among them and the week's standing. The
/// home asks for `ledgerDays`, and for `yearDays` only while the year is shown.
final rewardsProvider = FutureProvider.autoDispose.family<Rewards, int>((ref, days) => getMyRewards(days: days));

/// Every cat the author has, newest first.
final catsProvider = FutureProvider.autoDispose<List<Cat>>((ref) => listMyCats());

/// Every cat there is to earn, as shapes only — what a shelf with nothing on
/// it yet can show. The same list for every author, so it never changes under
/// a session.
final catCatalogueProvider = FutureProvider.autoDispose<List<CatSilhouette>>((ref) => listCatCatalogue());
