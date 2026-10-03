import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/dates.dart';
import 'package:ghostkey/core/words.dart';
import 'package:ghostkey/rewards/ledger.dart';
import 'package:ghostkey/server/dto/rewards.dart';

WordStatsDay day(String day, int written, {int total = 0}) => WordStatsDay(day: day, total: total, written: written);

/// `count` days ending on `last` (a Wednesday, 2026-09-09 by default), oldest
/// first.
List<WordStatsDay> series(int count, int Function(int i) written, {DateTime? last}) {
  final end = last ?? DateTime.utc(2026, 9, 9);
  return [
    for (var i = 0; i < count; i++)
      day(end.subtract(Duration(days: count - 1 - i)).toIso8601String().substring(0, 10), written(i)),
  ];
}

void main() {
  group('streak', () {
    test('counts back from today; an unwritten today does not break it', () {
      expect(currentStreak(series(5, (i) => i >= 2 ? 100 : 0)), 3);
      expect(currentStreak(series(5, (i) => i >= 2 && i < 4 ? 100 : 0)), 2);
      expect(currentStreak(series(5, (i) => 0)), 0);
      expect(currentStreak(const <WordStatsDay>[]), 0);
    });
  });

  group('wordColumns', () {
    test('a week is the last seven days, weekday letters, ticks by day', () {
      final days = series(30, (i) => i);
      final week = wordColumns(days, WordRange.week, {'2026-09-08'});
      expect(week.length, 7);
      expect(week.first.key, '2026-09-03');
      expect(week.last.key, '2026-09-09');
      expect(week.last.label, 'W');
      expect(week.last.written, 29);
      expect(week.where((c) => c.met).map((c) => c.key), ['2026-09-08']);
    });

    test('a month is the last thirty days, labelled by day of month', () {
      final month = wordColumns(series(30, (i) => 1), WordRange.month, const {});
      expect(month.length, 30);
      expect(month.last.label, '9');
      expect(columnsTotal(month), 30);
    });

    test('a year is twelve calendar months, summed, untickable', () {
      // 365 days ending 2026-10-02: the window opens on 2025-10-03, whose
      // October falls outside the twelve months shown.
      final days = series(365, (i) => 1, last: DateTime.utc(2026, 10, 2));
      final year = wordColumns(days, WordRange.year, {'2026-10-01'});
      expect(year.length, 12);
      expect(year.first.key, '2025-11');
      expect(year.first.label, 'Nov');
      expect(year.first.written, 30);
      expect(year[3].key, '2026-02');
      expect(year[3].written, 28);
      expect(year.last.key, '2026-10');
      expect(year.last.written, 2);
      expect(year.any((c) => c.met), isFalse);
    });

    test('an empty series has no columns', () {
      expect(wordColumns(const [], WordRange.year, const {}), isEmpty);
      expect(wordColumns(const [], WordRange.week, const {}), isEmpty);
    });

    test('the peak is the busiest column shown, never below one', () {
      expect(columnPeak(wordColumns(series(10, (i) => i == 0 ? 9000 : i * 10), WordRange.week, const {})), 90);
      expect(columnPeak(wordColumns(series(3, (i) => 0), WordRange.week, const {})), 1);
    });
  });

  group('labels', () {
    test('a stored day reads as a plain date, never shifted by a timezone', () {
      expect(dayLabel('2026-09-09'), 'Wed 09');
      expect(columnLabel('2026-09-09', weekday: true), 'W');
      expect(columnLabel('2026-09-09', weekday: false), '9');
      expect(dayLabel('nonsense'), 'nonsense');
    });

    test('relative time at a glance', () {
      final now = DateTime.utc(2026, 9, 9, 12);
      String at(Duration ago) => relativeTime(now.subtract(ago).toIso8601String(), now: now);
      expect(at(const Duration(seconds: 30)), 'just now');
      expect(at(const Duration(minutes: 20)), '20 min ago');
      expect(at(const Duration(hours: 3)), '3 h ago');
      expect(at(const Duration(hours: 26)), 'yesterday');
      expect(at(const Duration(days: 3)), '3 days ago');
      expect(at(const Duration(days: 20)), 'August 20');
    });

    test('plural', () {
      expect(plural(1, 'chapter'), '1 chapter');
      expect(plural(3, 'chapter'), '3 chapters');
    });
  });
}
