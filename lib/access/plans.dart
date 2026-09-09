import '../server/dto/billing.dart';

export '../core/dates.dart' show formatBillingDate;

// How mobile words a plan and a billing date.

String planName(Plan plan) => plan.displayName;

/// Whole days from now until `iso`, floored at 0. Rounded UP, so anything
/// still to come is at least 1. Null when open-ended.
int? daysLeft(String? iso) {
  if (iso == null) return null;
  final at = DateTime.tryParse(iso);
  if (at == null) return null;
  final ms = at.difference(DateTime.now()).inMilliseconds;
  return ms <= 0 ? 0 : (ms / (24 * 60 * 60 * 1000)).ceil();
}

/// "last day" / "3 days left" — null for an open-ended grant, and for one
/// already over.
String? daysLeftLabel(String? iso) {
  final left = daysLeft(iso);
  if (left == null || left == 0) return null;
  return left == 1 ? 'last day' : '$left days left';
}

/// A rung's price as the account screen prints it — "$9.99", "€19.99". Null
/// for a rung with no amount, which means *unknown*, not free.
String? formatPrice(int? amount, String? currency) {
  if (amount == null || amount <= 0 || currency == null) return null;
  final symbol = switch (currency.toLowerCase()) {
    'usd' => r'$',
    'eur' => '€',
    'gbp' => '£',
    'cad' => r'CA$',
    'aud' => r'A$',
    'chf' => 'CHF ',
    _ => '${currency.toUpperCase()} ',
  };
  final major = amount ~/ 100;
  final minor = (amount % 100).toString().padLeft(2, '0');
  return '$symbol$major.$minor';
}
