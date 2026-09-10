import 'json.dart';

// The media library, as far as this app touches it: one item, as the upload
// answers. Hand-written against the contract's MediaItem schema — the library
// has no room on the phone; the chat is its first caller here, for a file the
// author attaches.

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.bodyChars,
    required this.origin,
  });
  final String id;
  final String kind;
  final String title;

  /// The whole text on a single-item read (an upload answers with one); an
  /// excerpt on a listing, which `bodyChars` tells apart.
  final String body;
  final int bodyChars;
  final String origin;

  bool get bodyIsWhole => body.length >= bodyChars;

  static MediaItem fromJson(Json json) => MediaItem(
        id: asString(json['id']),
        kind: asString(json['kind']),
        title: asString(json['title']),
        body: asString(json['body']),
        bodyChars: asInt(json['body_chars']),
        origin: asString(json['origin']),
      );
}
