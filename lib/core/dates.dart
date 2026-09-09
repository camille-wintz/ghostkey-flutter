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
