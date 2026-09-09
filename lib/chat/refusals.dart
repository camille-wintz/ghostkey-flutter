import '../server/dto/billing.dart';

// What a send can come back with instead of an answer. Both are explained by
// a notice, never an error bar, and the message returns to the composer.

sealed class ComposerRefusal {
  const ComposerRefusal();
}

/// A spent counter — ahead of the call from the cached snapshot, or the
/// server's 402.
class QuotaRefusal extends ComposerRefusal {
  const QuotaRefusal({required this.feature, this.refused});

  /// The counter that refused — `phantom_chat`, or `fable_chat` when the
  /// premium pool is the spent one.
  final String feature;

  /// The 402 body when the server refused; null when the cached count did.
  /// Its numbers beat the snapshot's, which may be the stale one that let
  /// the send through.
  final QuotaExceeded? refused;
}

/// A 403 from a send, or a locked picker row.
class PlanDenied extends ComposerRefusal {
  const PlanDenied({required this.what, this.requiredPlan});

  /// What was refused — a model's name, or the server's label for a surface.
  final String what;
  final Plan? requiredPlan;
}
