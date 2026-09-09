// The room's own readings of time — the desktop's poltergeist/utils/time.ts.
// core/dates.dart speaks the shelf's compact form; the ledger wants these.

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> _weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "just now", "20 min ago", "3 h ago", "yesterday", then the date — the
/// resolution a glance at the dashboard needs.
String relativeTime(String iso, {DateTime? now}) {
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final minutes = ((now ?? DateTime.now()).difference(then).inSeconds / 60).round();
  if (minutes < 2) return 'just now';
  if (minutes < 60) return '$minutes min ago';
  final hours = (minutes / 60).round();
  if (hours < 24) return '$hours h ago';
  final days = (hours / 24).round();
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  final local = then.toLocal();
  return '${_monthsLong[local.month - 1]} ${local.day}';
}

/// How long ago, in the ledger's shorthand: "now", then m / h / d — the age
/// figure on a task row's right margin.
String shortAge(String iso, {DateTime? now}) {
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final mins = (now ?? DateTime.now()).difference(then).inMinutes;
  if (mins < 1) return 'now';
  if (mins < 60) return '${mins}m';
  final hours = mins ~/ 60;
  if (hours < 24) return '${hours}h';
  return '${hours ~/ 24}d';
}

/// A stored `YYYY-MM-DD` day as a plain date. It is already the author's
/// local calendar day, so it is never passed through a timezone.
DateTime? parseDay(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

/// The ledger row's label — "Tue 09".
String dayLabel(String day) {
  final d = parseDay(day);
  if (d == null) return day;
  return '${_weekdays[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}';
}

/// Under a column: a weekday letter for a week, the day of the month for a
/// longer run.
String columnLabel(String day, {required bool weekday}) {
  final d = parseDay(day);
  if (d == null) return '';
  return weekday ? _weekdayLetters[d.weekday - 1] : d.day.toString();
}

/// "Week of Aug 24".
String weekOfLabel(DateTime monday) => 'Week of ${_months[monday.month - 1]} ${monday.day}';

/// The dashboard's date line — "Tuesday, September 9".
String todayLabel(DateTime now) => '${_weekdaysLong[now.weekday - 1]}, ${_monthsLong[now.month - 1]} ${now.day}';
