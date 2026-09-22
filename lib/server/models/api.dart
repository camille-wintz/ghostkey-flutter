import '../client.dart';
import '../dto/models.dart';

/// Every model picker's rows, in display order. Unauthenticated like the plan
/// catalog: which models exist is the same answer for everyone. Whether this
/// account may pick a banded row is the access snapshot's to say.
Future<ModelCatalog> getModelCatalog() async {
  final res = await apiFetch('/api/models', auth: false);
  return ModelCatalog.fromJson(res.jsonObject());
}
