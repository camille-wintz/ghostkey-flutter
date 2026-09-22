import 'json.dart';

// The model pickers' wire shapes — `ModelCatalog`, `ModelSurface` and
// `CatalogModel` in openapi.yaml (GET /api/models). The server's catalog
// (ghostkey-server/src/lib/llm/catalog.ts) is the only copy of the list; the
// phone keeps none of its own since 2026-09-22.

/// One row of a picker. [capability] is a `Capability.id` in the access
/// snapshot (null: needs nothing beyond the surface); [quota] is the counter
/// this model spends on its own (null: the pooled chat allowance). Both only
/// draw — the server decides what is refused and charged.
class CatalogModel {
  const CatalogModel({required this.id, required this.name, this.capability, this.quota});

  final String id;
  final String name;
  final String? capability;
  final String? quota;

  static CatalogModel fromJson(Json json) {
    final id = asString(json['id']);
    return CatalogModel(
      id: id,
      // A nameless row is more use under its id than blank.
      name: asString(json['name'], id),
      capability: json['capability'] as String?,
      quota: json['quota'] as String?,
    );
  }
}

/// One place an author picks a model: `chat` or `edit_pass` today. [defaultId]
/// is the row it starts on, and what the server runs when a request names no
/// model.
class ModelSurface {
  const ModelSurface({required this.id, required this.defaultId, required this.models});

  final String id;
  final String defaultId;

  /// In display order.
  final List<CatalogModel> models;

  static ModelSurface fromJson(Json json) => ModelSurface(
        id: asString(json['id']),
        defaultId: asString(json['default']),
        // A row with no id could never be sent; drop it rather than draw it.
        models: asJsonList(json['models']).map(CatalogModel.fromJson).where((m) => m.id.isNotEmpty).toList(),
      );

  CatalogModel? model(String id) => models.where((m) => m.id == id).firstOrNull;

  /// The [defaultId] row; null only if the server names a default it does
  /// not list.
  CatalogModel? get defaultModel => model(defaultId);
}

class ModelCatalog {
  const ModelCatalog({required this.surfaces});

  final List<ModelSurface> surfaces;

  static ModelCatalog fromJson(Json json) =>
      ModelCatalog(surfaces: asJsonList(json['surfaces']).map(ModelSurface.fromJson).toList());

  /// A surface by id; null for one this server does not serve.
  ModelSurface? surface(String id) => surfaces.where((s) => s.id == id).firstOrNull;
}
