import '../server/dto/rewards.dart';

/// The week in one clause, for under a figure: how many days are ticked and
/// what that is worth. Reads as an invitation when there is no target yet.
/// Mirrors the desktop's `shared/rewards/week.ts`.
String weekLine(Rewards rewards) {
  final week = rewards.week;
  // The first cat is one day away, not five, so the invitation says so —
  // until it has been earned, when the week is the whole offer again.
  if (rewards.target == null) {
    return rewards.catsEarned == 0
        ? 'Set a daily target — reach it once for your first cat'
        : 'Set a daily target to start collecting cats';
  }
  if (week.catEarned) return "This week's cat is yours";
  final left = week.required - week.ticked;
  final ticked = '${week.ticked} of ${week.required} days this week';
  if (week.ticked == 0) return '$ticked · ${week.required} for a cat';
  return '$ticked · $left more for a cat';
}
