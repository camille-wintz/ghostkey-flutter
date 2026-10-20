import '../server/dto/billing.dart';

// What a send can come back with instead of an answer. Both are explained by
// a notice, never an error bar, and the message returns to the composer.

sealed class ComposerRefusal {
  const ComposerRefusal({this.counted = false});

  /// The server refused and already counted the wall
  /// (`ServerError.wallRecorded`); false when this side stopped the send, or
  /// a server that predates the flag refused it — the notice reports those.
  final bool counted;
}

/// A spent counter — ahead of the call from the cached snapshot, or the
/// server's 402.
class QuotaRefusal extends ComposerRefusal {
  const QuotaRefusal({required this.feature, this.refused, super.counted});

  /// The counter that refused — the chat's line, `credits` on a plan that
  /// pays for the chat out of its weekly credits.
  final String feature;

  /// The 402 body when the server refused; null when the cached count did.
  /// Its numbers beat the snapshot's, which may be the stale one that let
  /// the send through.
  final QuotaExceeded? refused;
}

/// A 403 from a send, or a locked picker row.
class PlanDenied extends ComposerRefusal {
  const PlanDenied({required this.what, this.requiredPlan, this.capability, super.counted});

  /// What was refused — a model's name, or the server's label for a surface.
  final String what;
  final Plan? requiredPlan;

  /// The capability that refused, when known — what the wall is reported as.
  final String? capability;
}
