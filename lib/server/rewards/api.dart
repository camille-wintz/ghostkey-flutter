import '../client.dart';
import '../dto/json.dart';
import '../dto/rewards.dart';

// The writing rewards' routes. The server owns every reward, and they are the
// author's, not a book's: a day's writing is every book's words added up,
// against one daily target on the account. A client asks what today's
// writing earned (after a save lands) and shows what comes back.

int _offset(int? tzOffsetMinutes) => tzOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;

/// Today's words, the ticked days over the last [days] local days and where
/// the week stands. The offset is this phone's, like the word stats'.
Future<Rewards> getMyRewards({int days = 30, int? tzOffsetMinutes}) async {
  final res = await apiFetch('/api/me/rewards?days=$days&tz_offset=${_offset(tzOffsetMinutes)}');
  return Rewards.fromJson(res.jsonObject());
}

/// Look at today's writing, in every book, and hand out whatever it has
/// earned since the last look. Idempotent: a claim with nothing new awards
/// nothing.
Future<RewardClaim> claimMyRewards({int? tzOffsetMinutes}) async {
  final res = await apiFetch('/api/me/rewards/claim', method: 'POST', body: {'tz_offset': _offset(tzOffsetMinutes)});
  return RewardClaim.fromJson(res.jsonObject());
}

/// Set (or clear, with null) the words a day the author is aiming for — one
/// target for the account. Returns the target now in force.
Future<int?> setMyDailyTarget(int? target) async {
  final res = await apiFetch('/api/me/rewards/target', method: 'PUT', body: {'target': target});
  return res.jsonObject()['target'] as int?;
}

/// Every cat the author has, newest first. Per account, not per book.
Future<List<Cat>> listMyCats() async {
  final res = await apiFetch('/api/me/cats');
  return asJsonList(res.jsonObject()['cats']).map(Cat.fromJson).toList();
}
