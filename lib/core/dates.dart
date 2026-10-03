const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Sep 9, 2026", or empty for an unparsable date.
String formatShortDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// A billing date as the account surfaces say it — "13 September 2026".
String formatBillingDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.day} ${_longMonths[d.month - 1]} ${d.year}';
}

/// Compact relative time — "just now", "5m ago", "3h ago", "2d ago", or a
/// date past a week.
String formatRelativeTime(String iso) {
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final secs = DateTime.now().difference(then).inSeconds.clamp(0, 1 << 40);
  if (secs < 60) return 'just now';
  final mins = (secs / 60).round();
  if (mins < 60) return '${mins}m ago';
  final hours = (mins / 60).round();
  if (hours < 24) return '${hours}h ago';
  final days = (hours / 24).round();
  if (days < 7) return '${days}d ago';
  return formatShortDate(iso);
}

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "just now", "20 min ago", "3 h ago", "yesterday", then the date — the
/// resolution a glance at where you left off needs.
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
  return '${_longMonths[local.month - 1]} ${local.day}';
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

/// A stored day as a label — "Tue 09".
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

/// A month's short name, 1-based — "Sep".
String monthLabel(int month) => _months[month - 1];
