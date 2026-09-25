import 'json.dart';

// The media library, as far as this app touches it: one item, as the upload
// or the single-item read answers. Hand-written against the contract's
// MediaItem schema — the library has no room on the phone; the chat is its
// caller here, for a file the author attaches and a picture a tool opens.

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.bodyChars,
    required this.origin,
    this.seriesId = '',
    this.assetId,
    this.previewAssetId,
  });
  final String id;

  /// `text`, `image`, `audio`, `video`, `link` … kept as the wire says it, so
  /// a kind added later reads as itself rather than failing the item.
  final String kind;
  final String title;

  /// The whole text on a single-item read (an upload answers with one); an
  /// excerpt on a listing, which `bodyChars` tells apart. A picture's caption.
  final String body;
  final int bodyChars;
  final String origin;

  /// The series whose library holds the item — the render base for
  /// [assetId] and [previewAssetId].
  final String seriesId;

  /// The item's bytes as a SERIES asset; null for an item with none.
  final String? assetId;

  /// A picture's bounded webp copy (`meta.preview_asset_id`); null when the
  /// original is small or the item is not a picture.
  final String? previewAssetId;

  bool get isImage => kind == 'image';

  bool get bodyIsWhole => body.length >= bodyChars;

  static MediaItem fromJson(Json json) => MediaItem(
        id: asString(json['id']),
        kind: asString(json['kind']),
        title: asString(json['title']),
        body: asString(json['body']),
        bodyChars: asInt(json['body_chars']),
        origin: asString(json['origin']),
        seriesId: asString(json['series_id']),
        assetId: _nonEmpty(json['asset_id']),
        previewAssetId: json['meta'] is Map ? _nonEmpty(json['meta']['preview_asset_id']) : null,
      );
}

String? _nonEmpty(Object? value) => value is String && value.isNotEmpty ? value : null;
