import 'json.dart';

// The world bible and its dossiers. Mirrors the `Bible*` / `Dossier*` families
// in openapi.yaml; diff against it when the contract moves.

enum BibleEntityType {
  character,
  place,
  term;

  static BibleEntityType fromWire(String? value) => switch (value) {
        'place' => BibleEntityType.place,
        'term' => BibleEntityType.term,
        _ => BibleEntityType.character,
      };

  String get label => switch (this) {
        BibleEntityType.character => 'Character',
        BibleEntityType.place => 'Place',
        BibleEntityType.term => 'Term',
      };

  String get plural => switch (this) {
        BibleEntityType.character => 'Characters',
        BibleEntityType.place => 'Places',
        BibleEntityType.term => 'Terms',
      };
}

/// Who put an entity in the bible: some book's model run, or the author by
/// hand. Only `user` cards are deletable; a hand-added name the extraction
/// later finds becomes `extracted` with the author's fields folded in.
enum BibleEntityOrigin {
  extracted,
  user;

  static BibleEntityOrigin fromWire(String? value) =>
      value == 'user' ? BibleEntityOrigin.user : BibleEntityOrigin.extracted;
}

/// One name a chapter sweep proposes. Nothing is stored until the author
/// answers: accepting writes an entity, declining writes a hidden one.
class NameCandidate {
  const NameCandidate({required this.name, required this.type, required this.note});
  final String name;
  final BibleEntityType type;
  final String note;

  static NameCandidate fromJson(Json json) => NameCandidate(
        name: asString(json['name']),
        type: BibleEntityType.fromWire(json['type'] as String?),
        note: asString(json['note']),
      );
}

class NameScanResponse {
  const NameScanResponse({required this.candidates, required this.scannedVersion});
  final List<NameCandidate> candidates;
  final int scannedVersion;

  static NameScanResponse fromJson(Json json) => NameScanResponse(
        candidates: asJsonList(json['candidates']).map(NameCandidate.fromJson).toList(),
        scannedVersion: asInt(json['scanned_version']),
      );
}

/// One book of a series-wide entity: whether it appears there and how.
/// Mirrors `BibleEntityBookRef`; every book of the series gets an entry,
/// including ones the entity never appears in.
class BibleEntityBook {
  const BibleEntityBook({
    required this.projectId,
    required this.title,
    required this.mentionCount,
    required this.chapters,
    this.notedChapters = const [],
    this.firstAppearance,
  });
  final String projectId;

  /// The book's name — the wire's `project_name`.
  final String title;
  final int mentionCount;

  /// Chapter FILENAMES mentioning the entity in this book.
  final List<String> chapters;

  /// Chapter filenames whose note names the entity in this book.
  final List<String> notedChapters;

  /// Filename of the earliest mention in this book; null when none.
  final String? firstAppearance;

  static BibleEntityBook fromJson(Json json) => BibleEntityBook(
        projectId: asString(json['project_id']),
        title: asString(json['project_name'] ?? json['title']),
        mentionCount: asInt(json['mention_count']),
        chapters: asStringList(json['chapters']),
        notedChapters: asStringList(json['noted_chapters']),
        firstAppearance: _nonEmpty(json['first_appearance']),
      );
}

/// The wire sends an empty string for "none"; null is the honest reading.
String? _nonEmpty(dynamic value) => value is String && value.isNotEmpty ? value : null;

/// One card of the roster. The extraction and author layers are merged
/// server-side; every field here is what the read model returns.
class BibleEntity {
  const BibleEntity({
    required this.id,
    required this.key,
    required this.type,
    required this.name,
    required this.hidden,
    required this.chapters,
    required this.mentionCount,
    required this.firstAppearance,
    required this.aliases,
    required this.facts,
    required this.notes,
    required this.description,
    required this.plannedChapters,
    required this.books,
    required this.raw,
    this.extractedName = '',
    this.notedChapters = const [],
    this.origin = BibleEntityOrigin.extracted,
    this.imageAssetId,
    this.imageFilename,
  });

  final String id;
  final String key;
  final BibleEntityType type;

  /// Canonical display form, post-override.
  final String name;
  final bool hidden;

  /// Chapter FILENAMES this entity is mentioned in, in this book.
  final List<String> chapters;
  final int mentionCount;
  final String? firstAppearance;
  final List<String> aliases;
  final List<String> facts;
  final String notes;
  final String description;
  /// Chapter DOCUMENT IDS the author plans this entity for, in this book.
  final List<String> plannedChapters;
  final List<BibleEntityBook> books;
  final Json raw;

  /// What the extraction chose before overrides — "renamed from …".
  final String extractedName;

  /// Chapter filenames whose NOTE names the entity, in this book. The third
  /// set beside `chapters` (what the prose does) and `plannedChapters` (what
  /// the author ticked): what their plan says.
  final List<String> notedChapters;
  final BibleEntityOrigin origin;

  /// SERIES asset id of the attached portrait, rendered through
  /// `/api/series/{series_id}/assets/{id}`. Null when none.
  final String? imageAssetId;
  final String? imageFilename;

  bool get isUser => origin == BibleEntityOrigin.user;

  /// Chapters mentioning this entity in `projectId` — the flat count for the
  /// book asked about when null.
  int mentionsIn(String? projectId) {
    if (projectId == null) return mentionCount;
    return books.where((b) => b.projectId == projectId).firstOrNull?.mentionCount ?? 0;
  }

  static BibleEntity fromJson(Json json) => BibleEntity(
        id: asString(json['id']),
        key: asString(json['key']),
        type: BibleEntityType.fromWire(json['type'] as String?),
        name: asString(json['name']),
        hidden: asBool(json['hidden']),
        chapters: asStringList(json['chapters']),
        mentionCount: asInt(json['mention_count']),
        firstAppearance: _nonEmpty(json['first_appearance']),
        aliases: asStringList(json['aliases']),
        facts: asStringList(json['facts']),
        notes: asString(json['notes'] ?? json['author_notes']),
        description: asString(json['description'] ?? json['physical_description']),
        plannedChapters: asStringList(json['planned_chapters']),
        books: asJsonList(json['books']).map(BibleEntityBook.fromJson).toList(),
        raw: json,
        extractedName: asString(json['extracted_name']),
        notedChapters: asStringList(json['noted_chapters']),
        origin: BibleEntityOrigin.fromWire(json['origin'] as String?),
        imageAssetId: _nonEmpty(json['image_asset_id']),
        imageFilename: _nonEmpty(json['image_filename']),
      );
}

class BibleResponse {
  const BibleResponse({
    required this.seriesId,
    required this.entities,
    required this.spellings,
    this.formatVersion = 0,
    this.generatedAt = '',
  });

  /// Null when no bible has been generated for this series yet.
  final String? seriesId;
  final List<BibleEntity> entities;
  final List<String> spellings;
  final int formatVersion;

  /// The newest extraction time across the series' books; empty when none
  /// has run.
  final String generatedAt;

  bool get exists => seriesId != null;

  /// Some book's model run has found something — as opposed to a bible the
  /// author has only ever filled by hand.
  bool get hasExtraction => entities.any((e) => e.origin == BibleEntityOrigin.extracted);

  static BibleResponse fromJson(Json json) {
    final bible = json['bible'];
    final body = bible is Map ? asJson(bible) : null;
    return BibleResponse(
      seriesId: body != null ? asString(body['series_id']) : null,
      entities: body != null ? asJsonList(body['entities']).map(BibleEntity.fromJson).toList() : const [],
      spellings: asStringList(json['spellings']),
      formatVersion: body != null ? asInt(body['format_version']) : 0,
      generatedAt: body != null ? asString(body['generated_at']) : '',
    );
  }
}

/// What a single-entity write answers: the refreshed bible, plus the id the
/// write landed on.
class BibleEntityWriteResponse {
  const BibleEntityWriteResponse({required this.id, required this.bible});
  final String id;
  final BibleResponse bible;

  static BibleEntityWriteResponse fromJson(Json json) => BibleEntityWriteResponse(
        id: asString(json['id']),
        bible: BibleResponse.fromJson(json),
      );
}

// ── Dossiers ─────────────────────────────────────────────────────────────

class DossierSection {
  const DossierSection({required this.title, required this.body});
  final String title;
  final String body;

  static DossierSection fromJson(Json json) =>
      DossierSection(title: asString(json['title']), body: asString(json['body']));
}

class DossierTimelineEntry {
  const DossierTimelineEntry({required this.chapter, required this.events});
  final String chapter;
  final List<String> events;

  static DossierTimelineEntry fromJson(Json json) =>
      DossierTimelineEntry(chapter: asString(json['chapter']), events: asStringList(json['events']));
}

class DossierGlanceItem {
  const DossierGlanceItem({required this.label, required this.value});
  final String label;
  final String value;

  static DossierGlanceItem fromJson(Json json) =>
      DossierGlanceItem(label: asString(json['label']), value: asString(json['value']));
}

class DossierTie {
  const DossierTie({required this.key, required this.name, required this.relation});
  final String key;
  final String name;
  final String relation;

  static DossierTie fromJson(Json json) => DossierTie(
        key: asString(json['key']),
        name: asString(json['name']),
        relation: asString(json['relation']),
      );
}

class Dossier {
  const Dossier({
    required this.key,
    required this.name,
    required this.type,
    required this.generatedAt,
    required this.chaptersUsed,
    required this.truncated,
    required this.overview,
    required this.appearance,
    required this.glance,
    required this.sections,
    required this.timeline,
    required this.ties,
    required this.stale,
  });

  final String key;
  final String name;
  final BibleEntityType type;
  final String generatedAt;
  final List<String> chaptersUsed;
  final bool truncated;
  final String overview;
  final String appearance;
  final List<DossierGlanceItem> glance;
  final List<DossierSection> sections;
  final List<DossierTimelineEntry> timeline;
  final List<DossierTie> ties;
  final bool stale;

  static Dossier fromJson(Json json) => Dossier(
        key: asString(json['key']),
        name: asString(json['name']),
        type: BibleEntityType.fromWire(json['type'] as String?),
        generatedAt: asString(json['generated_at']),
        chaptersUsed: asStringList(json['chapters_used']),
        truncated: asBool(json['truncated']),
        overview: asString(json['overview']),
        appearance: asString(json['appearance']),
        glance: asJsonList(json['glance']).map(DossierGlanceItem.fromJson).toList(),
        sections: asJsonList(json['sections']).map(DossierSection.fromJson).toList(),
        timeline: asJsonList(json['timeline']).map(DossierTimelineEntry.fromJson).toList(),
        ties: asJsonList(json['ties']).map(DossierTie.fromJson).toList(),
        stale: asBool(json['stale']),
      );
}
