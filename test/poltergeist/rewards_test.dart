import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/rewards.dart';
import 'package:ghostkey/server/dto/rewards.dart';

Rewards rewards({int? target, int ticked = 0, bool catEarned = false, int catsEarned = 0}) => Rewards(
      target: target,
      writtenToday: 0,
      days: const [],
      metDays: const [],
      week: RewardWeek(start: '2026-09-14', ticked: ticked, required: 5, catEarned: catEarned),
      catsEarned: catsEarned,
    );

void main() {
  group('weekLine', () {
    test('invites when there is no target', () {
      expect(weekLine(rewards()), 'Set a daily target — reach it once for your first cat');
      // Once the first cat is on the shelf, the week is the whole offer.
      expect(weekLine(rewards(catsEarned: 1)), 'Set a daily target to start collecting cats');
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
    test('a cat with an unknown reason reads as the ordinary one', () {
      final parsed = Cat.fromJson({
        'id': 'c2',
        'cat_id': 'custard',
        'name': 'Custard',
        'svg': '<svg></svg>',
        'reason': 'equinox',
        'earned_at': '2026-09-20T10:00:00Z',
        'week_start': '2026-09-14',
      });
      expect(parsed.reason, CatReason.week);
    });
  });
}
