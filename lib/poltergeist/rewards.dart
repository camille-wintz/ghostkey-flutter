import '../server/dto/rewards.dart';

/// The week in one clause, for under a figure: how many days are ticked and
/// what that is worth. Reads as an invitation when there is no target yet.
/// Mirrors the desktop's `shared/rewards/week.ts`.
String weekLine(Rewards rewards) {
  final week = rewards.week;
  if (rewards.target == null) return 'Set a daily target to start collecting cats';
  if (week.catEarned) return "This week's cat is yours";
  final left = week.required - week.ticked;
  final ticked = '${week.ticked} of ${week.required} days this week';
  if (week.ticked == 0) return '$ticked · ${week.required} for a cat';
  return '$ticked · $left more for a cat';
}

/// What to say about one thing the server just awarded. The server decided
/// the reward; this only puts it into words. The first line is the notice,
/// the second (when there is one) the quieter detail.
(String, String?) rewardWords(Reward reward) => switch (reward) {
      WordsReward(:final words) when words >= 500 => ("$words words today. You're doing amazing.", null),
      WordsReward(:final words) => ('$words words today — congratulations.', null),
      DayReward(:final daysToCat) => (
          'Daily target reached — congratulations.',
          daysToCat > 0
              ? "Keep writing for ${daysToCat == 1 ? 'one more day' : '$daysToCat more days'} this week and you'll get a cat."
              : 'A cat is on its way.',
        ),
      CatReward(:final cat) => ('A whole week of writing. Meet ${cat.name}.', 'Your new cat is waiting in Poltergeist.'),
    };
