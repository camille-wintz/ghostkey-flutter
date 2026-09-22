import '../access/capability.dart';
import '../server/dto/billing.dart';
import '../server/dto/models.dart';

const CapabilityState _open = CapabilityState(granted: true);

/// Whether a catalog row may be picked, from one access read: a row with no
/// capability is always open, a banded one reads its capability in the
/// snapshot. Optimistic while the snapshot loads, like every other lock in the
/// app.
CapabilityState modelAccess(AccessSnapshot? snapshot, CatalogModel model) {
  final capability = model.capability;
  return capability == null ? _open : capabilityFrom(snapshot, capability);
}
