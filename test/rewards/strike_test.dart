import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/rewards/strike.dart';
import 'package:ghostkey/rewards/strikes.dart';
import 'package:ghostkey/server/dto/rewards.dart';

RewardClaim claim({int written = 120, int? target, bool met = false, int ticked = 0}) => RewardClaim(
      writtenToday: written,
      target: target,
      metToday: met,
      week: RewardWeek(start: '2026-09-14', ticked: ticked, required: 5, catEarned: false),
      awarded: const [],
    );

Cat cat({CatReason reason = CatReason.week}) => Cat(
      id: 'c1',
      catId: 'peony',
      name: 'Peony',
      svg: '<svg></svg>',
      reason: reason,
      earnedAt: '2026-09-20T10:00:00Z',
      weekStart: '2026-09-14',
    );

void main() {
  group('strikeFor', () {
    test('a word mark names the next one and closes the ring towards it', () {
      final s = strikeFor(const WordsReward(100), claim(written: 120));
      expect(s.headline, '100 words');
      expect(s.sub, "100 words written today! You're on your way.");
      expect(s.footnote, 'Next at 500');
      expect(s.ring, closeTo(0.24, 0.001));
      // No target, nothing to tick: the chain stays off the card.
      expect(s.ticked, isNull);
      expect(s.cat, isNull);
    });
    test('a word mark says how far the daily goal is', () {
      final s = strikeFor(const WordsReward(100), claim(written: 120, target: 1500, ticked: 2));
      expect(s.sub, "100 words written today! You're on your way. 1,380 more to your daily goal.");
      expect(s.ticked, 2);
      // Met already: nothing to count down to.
      expect(strikeFor(const WordsReward(500), claim(written: 520, target: 300, met: true)).sub,
          "500 words written already. You're doing amazing!");
    });
    test('the last word mark is kept, and the ring is full', () {
      final s = strikeFor(const WordsReward(500), claim(written: 520));
      expect(s.footnote, 'Kept in Poltergeist');
      expect(s.ring, 1);
    });
    test('the day counts the week', () {
      final s = strikeFor(const DayReward(daysToCat: 2), claim(written: 320, target: 300, met: true, ticked: 3));
      expect(s.headline, 'Day 3');
      expect(s.sub, "Congratulations! You've completed your daily goal. Keep writing for two more days and you'll get a cat.");
      expect(strikeFor(const DayReward(daysToCat: 1), claim(target: 300, ticked: 4)).sub,
          "Congratulations! You've completed your daily goal. Keep writing for one more day and you'll get a cat.");
      // No cat in the same claim and nothing left to count: the week's is
      // already on the shelf.
      expect(strikeFor(const DayReward(daysToCat: 0), claim(target: 300, ticked: 6)).sub,
          "Congratulations! You've completed your daily goal. This week's cat is already yours.");
      expect(s.ring, 1);
      expect(s.ticked, 3);
    });
    test('the welcome cat says the goal was reached, the week cat says the week', () {
      // The cat stands in for the tick, so its words are the only notice.
      final first = strikeFor(CatReward(cat(reason: CatReason.firstGoal)), claim(target: 300, met: true, ticked: 1));
      expect(first.eyebrow, 'Your first goal');
      expect(first.headline, 'Peony');
      expect(first.sub, "You've reached your daily goal for the first time! Here is a cat as a well-earned reward.");
      expect(first.cat, isNotNull);
      final week = strikeFor(CatReward(cat()), claim(target: 300, met: true, ticked: 5));
      expect(week.eyebrow, 'A full week');
      expect(week.sub, "You've completed your weekly goal! Here is a cat for your trouble.");
      expect(week.footnote, 'Added to Poltergeist');
    });
  });

  group('RewardStrikes', () {
    test('strikes one at a time, the next once the last has gone', () {
      final strikes = RewardStrikes();
      final c = claim(written: 320, target: 300, met: true, ticked: 1);
      strikes.show(strikeFor(const WordsReward(100), c));
      strikes.show(strikeFor(const DayReward(daysToCat: 4), c));
      expect(strikes.current?.strike.headline, '100 words');
      expect(strikes.current?.leaving, isFalse);

      strikes.dismiss();
      expect(strikes.current?.strike.headline, '100 words');
      expect(strikes.current?.leaving, isTrue);
      // A stale id changes nothing.
      strikes.gone(-1);
      expect(strikes.current?.leaving, isTrue);

      strikes.gone(strikes.current!.id);
      expect(strikes.current?.strike.headline, 'Day 1');
      expect(strikes.current?.leaving, isFalse);

      strikes.dismiss();
      strikes.gone(strikes.current!.id);
      expect(strikes.current, isNull);
      strikes.dispose();
    });
  });
}
