import '../server/dto/poltergeist.dart';
import 'time.dart';

/// The window the ledger reads — the desktop's LEDGER_DAYS.
const int ledgerDays = 30;

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

/// The trailing week's best day — the scale every bar in the room is drawn
/// against, so the current week always reads at full size and an older,
/// bigger day clips at 100%.
int weekPeak(List<WordStatsDay> days) {
  final week = days.length > 7 ? days.sublist(days.length - 7) : days;
  var peak = 1;
  for (final d in week) {
    if (d.written > peak) peak = d.written;
  }
  return peak;
}

/// The last seven entries, oldest first.
List<WordStatsDay> lastWeek(List<WordStatsDay> days) => days.length > 7 ? days.sublist(days.length - 7) : days;

/// One ruled section of the phone's ledger: a Monday-to-Sunday week, its
/// days newest first, and the words it holds.
class LedgerWeek {
  const LedgerWeek({required this.label, required this.days, required this.written});
  final String label;
  final List<WordStatsDay> days;
  final int written;
}

/// The series cut into weeks, newest week first, days newest first inside
/// each. The week holding the series' last day is "This week", the one
/// before "Last week", the rest "Week of &lt;Monday&gt;". The desktop lists the
/// thirty days bare; a phone's list wants the rule between weeks.
List<LedgerWeek> ledgerWeeks(List<WordStatsDay> days) {
  if (days.isEmpty) return const [];
  DateTime? mondayOf(String day) {
    final d = parseDay(day);
    return d?.subtract(Duration(days: d.weekday - 1));
  }

  final thisMonday = mondayOf(days.last.day);
  final groups = <DateTime, List<WordStatsDay>>{};
  final order = <DateTime>[];
  for (final day in days.reversed) {
    final monday = mondayOf(day.day);
    if (monday == null) continue;
    final group = groups.putIfAbsent(monday, () {
      order.add(monday);
      return [];
    });
    group.add(day);
  }

  return [
    for (final monday in order)
      LedgerWeek(
        label: thisMonday == null
            ? weekOfLabel(monday)
            : monday == thisMonday
                ? 'This week'
                : monday == thisMonday.subtract(const Duration(days: 7))
                    ? 'Last week'
                    : weekOfLabel(monday),
        days: groups[monday]!,
        written: groups[monday]!.fold(0, (sum, d) => sum + d.written),
      ),
  ];
}
