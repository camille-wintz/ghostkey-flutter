import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/models.dart';
import '../server/providers.dart';

// The chat picker's models come from the server's catalog (GET /api/models)
// since 2026-09-22; the list, its order, its names and its default are the
// server's. The phone draws the `chat` surface only — its line edit sends no
// model.
//
// The picked model means what the author picked: null until they pick one,
// and a turn then sends no `model`, so the server's default answers. The
// surface's `default` row stands in for it on screen.

/// The weekly counter every chat message draws from.
const String chatQuotaFeature = 'phantom_chat';

/// The catalog surface this app's chat picker draws.
const String chatSurfaceId = 'chat';

/// The chat surface, or null while the catalog loads, when it failed
/// (offline), or when the server serves no chat surface — every one of which
/// is a picker with nothing to pick.
final chatModelsProvider = Provider<ModelSurface?>(
  (ref) => ref.watch(modelCatalogProvider).value?.surface(chatSurfaceId),
);

/// The row a send is gated and labelled as: the picked one, else the
/// surface's default. Null when there is no surface, or the picked id is not
/// in it (a retired id the server still resolves).
CatalogModel? chatModelRow(ModelSurface? surface, String? picked) =>
    picked == null ? surface?.defaultModel : surface?.model(picked);

/// The name to say for the chat's model: the row's name; the raw id when the
/// catalog does not list it, since that is more use than "Unknown model"; null
/// when nothing is picked and the catalog has not landed.
String? chatModelLabel(ModelSurface? surface, String? picked) =>
    chatModelRow(surface, picked)?.name ?? picked;
