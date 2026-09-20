import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/rewards.dart';
import 'package:ghostkey/server/dto/rewards.dart';

Rewards rewards({int? target, int ticked = 0, bool catEarned = false}) => Rewards(
      target: target,
      writtenToday: 0,
      days: const [],
      metDays: const [],
      week: RewardWeek(start: '2026-09-14', ticked: ticked, required: 5, catEarned: catEarned),
      catsEarned: 0,
    );

void main() {
  group('weekLine', () {
    test('invites when there is no target', () {
      expect(weekLine(rewards()), 'Set a daily target to start collecting cats');
    });
    test('counts the week towards the cat', () {
      expect(weekLine(rewards(target: 300)), '0 of 5 days this week · 5 for a cat');
      expect(weekLine(rewards(target: 300, ticked: 3)), '3 of 5 days this week · 2 more for a cat');
      expect(weekLine(rewards(target: 300, ticked: 5, catEarned: true)), "This week's cat is yours");
    });
  });

  group('rewards', () {
    test('parse what the server awarded and skip what this build does not know', () {
      final claim = RewardClaim.fromJson({
        'written_today': 520,
        'target': 100,
        'met_today': true,
        'week': {'start': '2026-09-14', 'ticked': 1, 'required': 5, 'cat_earned': false},
        'awarded': [
          {'kind': 'words', 'words': 500},
          {'kind': 'day', 'days_to_cat': 4},
          {'kind': 'ribbon', 'colour': 'blue'},
        ],
      });
      expect(claim.awarded.length, 2);
      expect((claim.awarded[0] as WordsReward).words, 500);
      expect((claim.awarded[1] as DayReward).daysToCat, 4);
    });
    test('are put into words', () {
      expect(rewardWords(const WordsReward(100)).$1, '100 words today — congratulations.');
      expect(rewardWords(const WordsReward(500)).$1, "500 words today. You're doing amazing.");
      final (text, detail) = rewardWords(const DayReward(daysToCat: 1));
      expect(text, 'Daily target reached — congratulations.');
      expect(detail, "Keep writing for one more day this week and you'll get a cat.");
      expect(rewardWords(const DayReward(daysToCat: 3)).$2, "Keep writing for 3 more days this week and you'll get a cat.");
    });
  });
}
