// The chat picker's models. Hand-mirrors the desktop's
// ghost-key/src/shared/models/models.ts (which itself mirrors the server's
// registry) — this app has no shared package to import from. Nothing gates
// the drift; update both in the same change. `minimax-m3` is in the wire enum
// but in neither picker, on purpose.

/// The band a model needs beyond the chat itself, as the access snapshot
/// names it.
enum ModelCapability {
  advanced('models.advanced'),
  premium('models.premium');

  const ModelCapability(this.id);
  final String id;
}

class ModelDef {
  const ModelDef({required this.id, required this.name, this.capability, this.quota});

  final String id;
  final String name;

  /// Absent for the included band. Draws the padlock — the server decides
  /// what is refused.
  final ModelCapability? capability;

  /// The counter this model draws down on its own, when it has one. Names
  /// the right counter in the quota notice; the server decides what is
  /// charged.
  final String? quota;
}

/// The included set first, then the premium band, so the one padlock a Basic
/// author sees sits at the bottom. The head of the list is the default, and it
/// has to be a model every paying plan includes: Sol leads again since
/// 2026-09-10, where Opus led for a day from the same date, when the
/// `models.advanced` band dropped to Basic — the id stays on Sol and Opus
/// because the padlock reads it, and the server keeps it granted at Basic so
/// that read draws no lock.
///
/// Sol over Opus because of the voice a new author meets first: on an empty
/// project's opening turn Opus was cold and self-justifying where Sol was warm.
/// Keep this order in step with the server's `DEFAULT_CHAT_MODEL`
/// (ghostkey-server/src/lib/chat/turn.ts) and the desktop catalog
/// (ghost-key/src/shared/models/models.ts) — nothing gates the drift.
const List<ModelDef> models = [
  ModelDef(id: 'gpt-5-6-sol', name: 'GPT-5.6 Sol', capability: ModelCapability.advanced),
  ModelDef(id: 'opus-4-8', name: 'Claude Opus 4.8', capability: ModelCapability.advanced),
  ModelDef(id: 'gpt-5-6-terra', name: 'GPT-5.6 Terra'),
  ModelDef(id: 'gemini-3-1-pro', name: 'Gemini 3.1 Pro'),
  ModelDef(id: 'glm-5-2', name: 'GLM 5.2'),
  ModelDef(id: 'sonnet-5', name: 'Claude Sonnet 5'),
  ModelDef(id: 'kimi-k3', name: 'Kimi K3'),
  ModelDef(id: 'qwen3-8-max', name: 'Qwen3.8 Max'),
  ModelDef(id: 'fable-5', name: 'Claude Fable 5', capability: ModelCapability.premium, quota: 'fable_chat'),
  // **GPT-6 Astra belongs here and is deliberately withheld** (2026-09-07),
  // matching the desktop catalog — see the long note in
  // ghost-key/src/shared/models/models.ts. It is wired everywhere else (server
  // registry, premium band, sharing Fable's `fable_chat` pool), but OpenAI is
  // rolling it out by spend tier and this account is below it, so every call
  // 403s. To ship it when the tier lands, restore every catalog together:
  //   ModelDef(id: 'gpt-6-astra', name: 'GPT-6 Astra', capability: ModelCapability.premium, quota: 'fable_chat'),
];

const String defaultModel = 'gpt-5-6-sol';

/// The weekly counter every chat message draws from.
const String chatQuotaFeature = 'phantom_chat';

ModelDef? modelDef(String id) {
  for (final m in models) {
    if (m.id == id) return m;
  }
  return null;
}

/// Display name for an id; the raw id when the list has drifted behind the
/// server's, since that is more use than "Unknown model".
String modelName(String id) => modelDef(id)?.name ?? id;
