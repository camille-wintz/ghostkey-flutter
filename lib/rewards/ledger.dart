import '../core/dates.dart';
import '../server/dto/rewards.dart';

/// The window the week and month read — the desktop's LEDGER_DAYS.
const int ledgerDays = 30;

/// The window the year reads: the server's ceiling, asked for only while the
/// year is the one on screen.
const int yearDays = 365;

/// The three spans the words chart can show.
enum WordRange { week, month, year }

/// Days a range asks the server for.
int daysFor(WordRange range) => range == WordRange.year ? yearDays : ledgerDays;

/// One column of the words chart: a day, or a calendar month for the year.
typedef WordColumn = ({String key, String label, int written, bool met});

/// Consecutive days of writing ending today. A day that has not been written
/// in yet doesn't break the streak — the day isn't over.
int currentStreak(List<WordStatsDay> days) {
  var streak = 0;
  for (var i = days.length - 1; i >= 0; i--) {
    if (days[i].written > 0) {
      streak++;
    } else if (i < days.length - 1) {
      break;
    }
  }
  return streak;
}

/// The series as the range's columns, oldest first, the current one last.
/// A week is the last seven days and a month the last thirty, a column a
/// day, each ticked when the day met the target. A year is the last twelve
/// calendar months, each the sum of its days, with no ticks — a tick is a
/// day's.
List<WordColumn> wordColumns(List<WordStatsDay> days, WordRange range, Set<String> metDays) {
  if (range == WordRange.year) return _months(days);
  final count = range == WordRange.week ? 7 : 30;
  final span = days.length > count ? days.sublist(days.length - count) : days;
  return [
    for (final d in span)
      (
        key: d.day,
        label: columnLabel(d.day, weekday: range == WordRange.week),
        written: d.written,
        met: metDays.contains(d.day),
      ),
  ];
}

List<WordColumn> _months(List<WordStatsDay> days) {
  final last = days.isEmpty ? null : parseDay(days.last.day);
  if (last == null) return const [];
  final totals = <int, int>{};
  for (final d in days) {
    final date = parseDay(d.day);
    if (date == null) continue;
    final key = date.year * 12 + date.month - 1;
    totals[key] = (totals[key] ?? 0) + d.written;
  }
  final current = last.year * 12 + last.month - 1;
  return [
    for (var key = current - 11; key <= current; key++)
      (
        key: '${key ~/ 12}-${(key % 12 + 1).toString().padLeft(2, '0')}',
        label: monthLabel(key % 12 + 1),
        written: totals[key] ?? 0,
        met: false,
      ),
  ];
}

/// The busiest column shown, never below one — what every bar is drawn
/// against.
int columnPeak(List<WordColumn> columns) =>
    columns.fold(1, (peak, c) => c.written > peak ? c.written : peak);

/// Words across the columns shown.
int columnsTotal(List<WordColumn> columns) => columns.fold(0, (sum, c) => sum + c.written);
