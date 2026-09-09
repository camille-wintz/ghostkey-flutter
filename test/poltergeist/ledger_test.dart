import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/ledger.dart';
import 'package:ghostkey/poltergeist/numbers.dart';
import 'package:ghostkey/poltergeist/time.dart';
import 'package:ghostkey/server/dto/poltergeist.dart';

WordStatsDay day(String day, int written, {int total = 0}) => WordStatsDay(day: day, total: total, written: written);

/// `count` days ending on `last` (a Wednesday, 2026-09-09), oldest first.
List<WordStatsDay> series(int count, int Function(int i) written) {
  final last = DateTime.utc(2026, 9, 9);
  return [
    for (var i = 0; i < count; i++)
      day(last.subtract(Duration(days: count - 1 - i)).toIso8601String().substring(0, 10), written(i)),
  ];
}

void main() {
  group('streak', () {
    test('counts back from today; an unwritten today does not break it', () {
      expect(currentStreak(series(5, (i) => i >= 2 ? 100 : 0)), 3);
      expect(currentStreak(series(5, (i) => i >= 2 && i < 4 ? 100 : 0)), 2);
      expect(currentStreak(series(5, (i) => 0)), 0);
      expect(currentStreak(const []), 0);
    });
  });

  group('weekPeak', () {
    test('is the trailing week\'s best day, never below one', () {
      expect(weekPeak(series(10, (i) => i == 0 ? 9000 : i * 10)), 90);
      expect(weekPeak(series(3, (i) => 0)), 1);
    });
  });

  group('ledgerWeeks', () {
    test('cuts the series into Monday weeks, newest first, days newest first', () {
      final days = series(12, (i) => i + 1);
      final weeks = ledgerWeeks(days);
      // Sep 9 2026 is a Wednesday: this week holds Mon 7 – Wed 9.
      expect(weeks.map((w) => w.label), ['This week', 'Last week', 'Week of Aug 24']);
      expect(weeks[0].days.map((d) => d.day), ['2026-09-09', '2026-09-08', '2026-09-07']);
      expect(weeks[0].written, 12 + 11 + 10);
      expect(weeks[1].days.length, 7);
      expect(weeks[2].days.map((d) => d.day), ['2026-08-30', '2026-08-29']);
      expect(weeks.fold(0, (sum, w) => sum + w.days.length), 12);
    });

    test('an empty series has no weeks', () {
      expect(ledgerWeeks(const []), isEmpty);
    });
  });

  group('labels', () {
    test('a stored day reads as a plain date, never shifted by a timezone', () {
      expect(dayLabel('2026-09-09'), 'Wed 09');
      expect(columnLabel('2026-09-09', weekday: true), 'W');
      expect(columnLabel('2026-09-09', weekday: false), '9');
      expect(dayLabel('nonsense'), 'nonsense');
    });

    test('relative time in the dashboard\'s resolution', () {
      final now = DateTime.utc(2026, 9, 9, 12);
      String at(Duration ago) => relativeTime(now.subtract(ago).toIso8601String(), now: now);
      expect(at(const Duration(seconds: 30)), 'just now');
      expect(at(const Duration(minutes: 20)), '20 min ago');
      expect(at(const Duration(hours: 3)), '3 h ago');
      expect(at(const Duration(hours: 26)), 'yesterday');
      expect(at(const Duration(days: 3)), '3 days ago');
      expect(at(const Duration(days: 20)), 'August 20');
    });

    test('short age for a task row', () {
      final now = DateTime.utc(2026, 9, 9, 12);
      String at(Duration ago) => shortAge(now.subtract(ago).toIso8601String(), now: now);
      expect(at(Duration.zero), 'now');
      expect(at(const Duration(minutes: 5)), '5m');
      expect(at(const Duration(hours: 7)), '7h');
      expect(at(const Duration(days: 2, hours: 3)), '2d');
    });
  });

  group('spellNumber', () {
    test('spells up to ninety-nine, then falls back to digits', () {
      expect(spellNumber(0), 'zero');
      expect(spellNumber(7), 'seven');
      expect(spellNumber(20), 'twenty');
      expect(spellNumber(61), 'sixty-one');
      expect(spellNumber(100), '100');
      expect(spellNumber(12345), '12 345');
      expect(plural(1, 'chapter'), '1 chapter');
      expect(plural(3, 'chapter'), '3 chapters');
    });
  });
}
