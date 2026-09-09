import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/billing.dart';
import '../server/providers.dart';

class CapabilityState {
  const CapabilityState({required this.granted, this.label, this.requiredPlan});
  final bool granted;

  /// Author-facing name, from the server. Absent until the snapshot lands.
  final String? label;

  /// The plan that opens it, for the padlock's copy. Absent when unknown.
  final Plan? requiredPlan;
}

/// Optimistic default, as on the desktop: a control that renders unlocked and
/// then 403s is a worse experience than one that renders locked — but one
/// that renders *locked* because a fetch was slow is worse than both. The
/// server is the authority either way.
const _optimistic = CapabilityState(granted: true);

/// One capability's state out of a snapshot — optimistic while there is no
/// snapshot (loading, failed) and for ids this server has never heard of.
CapabilityState capabilityFrom(AccessSnapshot? snapshot, String id) {
  final found = snapshot?.capabilities.where((c) => c.id == id).firstOrNull;
  if (found == null) return _optimistic;
  return CapabilityState(granted: found.granted, label: found.label, requiredPlan: found.requiredPlan);
}

/// One capability's state — `ref.watch(capabilityProvider('room.phantom'))`.
final capabilityProvider = Provider.family<CapabilityState, String>((ref, id) {
  final snapshot = ref.watch(accessProvider).value;
  return capabilityFrom(snapshot, id);
});
