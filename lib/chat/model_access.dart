import '../access/capability.dart';
import '../server/dto/billing.dart';
import 'models.dart';

const CapabilityState _open = CapabilityState(granted: true);

/// Whether a model may be picked, from one access read: the included band is
/// always open, a banded model reads its band's capability. Optimistic while
/// the snapshot loads, like every other lock in the app.
CapabilityState modelAccess(AccessSnapshot? snapshot, String modelId) {
  final capability = modelDef(modelId)?.capability;
  return capability == null ? _open : capabilityFrom(snapshot, capability.id);
}
