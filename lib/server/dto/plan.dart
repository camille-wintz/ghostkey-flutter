import 'json.dart';

// The author's plan as the chat's Review reads it: their boards (StoryMap,
// authored rows only) and the Outline page (AuthoredOutline, `text` only —
// the proposal and changeset belong to the desk's Chapters page).

/// One card of a board. `kind: label` is a section mark, not a beat. `cards`
/// is only ever filled on boards saved before the plan went flat; readers
/// flatten it.
class StoryCard {
  const StoryCard({
    required this.id,
    required this.title,
    required this.description,
    required this.isLabel,
    required this.chapters,
    required this.cards,
  });
  final String id;
  final String title;
  final String description;
  final bool isLabel;
  final List<String> chapters;
  final List<StoryCard> cards;

  static StoryCard fromJson(Json json) => StoryCard(
        id: asString(json['id']),
        title: asString(json['title']),
        description: asString(json['description']),
        isLabel: json['kind'] == 'label',
        chapters: asStringList(json['chapters']),
        cards: asJsonList(json['cards']).map(StoryCard.fromJson).toList(),
      );
}

class StoryMap {
  const StoryMap({required this.id, required this.name, required this.source, required this.nodes});
  final String id;

  /// The author's own name; null takes the structure's.
  final String? name;

  /// `authored` (a board) or `derived` (the book_map job's cache).
  final String source;
  final List<StoryCard> nodes;

  bool get authored => source == 'authored';

  static StoryMap fromJson(Json json) => StoryMap(
        id: asString(json['id']),
        name: json['name'] as String?,
        source: asString(json['source']),
        nodes: asJsonList(json['nodes']).map(StoryCard.fromJson).toList(),
      );
}

class AuthoredOutline {
  const AuthoredOutline({required this.text});

  /// The author's outline, markdown. Empty until they write one.
  final String text;

  static AuthoredOutline fromJson(Json json) => AuthoredOutline(text: asString(json['text']));
}
