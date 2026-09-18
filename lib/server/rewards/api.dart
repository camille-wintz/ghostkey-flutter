import '../client.dart';
import '../dto/json.dart';
import '../dto/rewards.dart';
import '../projects/api.dart';

// The writing rewards' routes. The server owns every reward: a client asks
// what today's writing earned (after a save lands) and shows what comes back.

/// The ticked days over the last [days] local days and where the week
/// stands. The offset is this phone's, like the word stats'.
Future<Rewards> getProjectRewards(String projectId, {int days = 30, int? tzOffsetMinutes}) async {
  final offset = tzOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
  final res = await apiFetch('/api/projects/$projectId/rewards?days=$days&tz_offset=$offset');
  return Rewards.fromJson(res.jsonObject());
}

/// Look at today's writing and hand out whatever it has earned since the
/// last look. Idempotent: a claim with nothing new awards nothing.
Future<RewardClaim> claimProjectRewards(String projectId, {int? tzOffsetMinutes}) async {
  final offset = tzOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
  final res = await apiFetch('/api/projects/$projectId/rewards/claim', method: 'POST', body: {'tz_offset': offset});
  return RewardClaim.fromJson(res.jsonObject());
}

/// Set (or clear, with null) the words-per-day the book is aiming for.
Future<int?> setDailyTarget(String projectId, int? target) async {
  final project = await patchProject(projectId, dailyTarget: Optional(target));
  return project.dailyTarget;
}

/// Every cat the author has, newest first. Per account, not per book.
Future<List<Cat>> listMyCats() async {
  final res = await apiFetch('/api/me/cats');
  return asJsonList(res.jsonObject()['cats']).map(Cat.fromJson).toList();
}
