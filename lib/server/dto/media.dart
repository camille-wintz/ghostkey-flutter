import 'json.dart';

// The series' media library, hand-written against the contract's MediaItem,
// MediaFolder and MediaSearchHit schemas. The phone reaches it as a picker
// (lib/screens/media/) from wherever a picture is wanted — a Veil portrait,
// a Veil gallery, the chat's attach — and the chat's Review reads one item
// a tool opened.

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.bodyChars,
    required this.origin,
    this.seriesId = '',
    this.folderId,
    this.assetId,
    this.url,
    this.previewAssetId,
    this.width,
    this.height,
    this.captionBy,
    this.prompt,
    this.version = 0,
    this.createdAt = '',
    this.updatedAt = '',
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

  /// Null for an item in no folder ("Unfiled").
  final String? folderId;

  /// The item's bytes as a SERIES asset; null for an item with none.
  final String? assetId;

  /// A link's address; null for anything else.
  final String? url;

  /// A picture's bounded webp copy (`meta.preview_asset_id`); null when the
  /// original is small or the item is not a picture.
  final String? previewAssetId;

  /// A picture's size in pixels, when the server knows it.
  final int? width;
  final int? height;

  /// Who wrote a picture's caption: `model`, `none`, or `prompt` for a drawn
  /// one, whose [prompt] the caption also is.
  final String? captionBy;
  final String? prompt;

  /// Bumps when the title or the body changes, and on nothing else.
  final int version;

  /// ISO timestamps, as the wire sends them.
  final String createdAt;
  final String updatedAt;

  bool get isImage => kind == 'image';

  bool get bodyIsWhole => body.length >= bodyChars;

  /// What a grid draws: the bounded copy when there is one.
  String? get thumbAssetId => previewAssetId ?? assetId;

  static MediaItem fromJson(Json json) {
    final meta = json['meta'] is Map ? asJson(json['meta']) : const <String, dynamic>{};
    return MediaItem(
      id: asString(json['id']),
      kind: asString(json['kind']),
      title: asString(json['title']),
      body: asString(json['body']),
      bodyChars: asInt(json['body_chars']),
      origin: asString(json['origin']),
      seriesId: asString(json['series_id']),
      folderId: _nonEmpty(json['folder_id']),
      assetId: _nonEmpty(json['asset_id']),
      url: _nonEmpty(json['url']),
      previewAssetId: _nonEmpty(meta['preview_asset_id']),
      width: meta['width'] is num ? (meta['width'] as num).toInt() : null,
      height: meta['height'] is num ? (meta['height'] as num).toInt() : null,
      captionBy: _nonEmpty(meta['caption_by']),
      prompt: _nonEmpty(meta['prompt']),
      version: asInt(json['version']),
      createdAt: asString(json['created_at']),
      updatedAt: asString(json['updated_at']),
    );
  }
}

class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    this.seriesId = '',
    this.sortIndex = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });
  final String id;
  final String name;
  final String seriesId;
  final int sortIndex;
  final String createdAt;
  final String updatedAt;

  static MediaFolder fromJson(Json json) => MediaFolder(
        id: asString(json['id']),
        name: asString(json['name']),
        seriesId: asString(json['series_id']),
        sortIndex: asInt(json['sort_index']),
        createdAt: asString(json['created_at']),
        updatedAt: asString(json['updated_at']),
      );
}

/// `GET /media`: every live item, newest first, and the folders.
class MediaLibrary {
  const MediaLibrary({required this.items, required this.folders});
  final List<MediaItem> items;
  final List<MediaFolder> folders;

  static MediaLibrary fromJson(Json json) => MediaLibrary(
        items: asJsonList(json['items']).map(MediaItem.fromJson).toList(),
        folders: asJsonList(json['folders']).map(MediaFolder.fromJson).toList(),
      );
}

/// One search answer. [score] is null for a keyword hit, the only kind the
/// phone asks for.
class MediaSearchHit {
  const MediaSearchHit({required this.item, this.score, this.snippet});
  final MediaItem item;
  final double? score;
  final String? snippet;

  static MediaSearchHit fromJson(Json json) => MediaSearchHit(
        item: MediaItem.fromJson(asJson(json['item'])),
        score: json['score'] is num ? (json['score'] as num).toDouble() : null,
        snippet: _nonEmpty(json['snippet']),
      );
}

/// The single-item read: the whole item, and how many world-bible cards
/// show it (as portrait or in a gallery) — what a removal asks about first.
class MediaItemRead {
  const MediaItemRead({required this.item, required this.cards});
  final MediaItem item;
  final int cards;

  static MediaItemRead fromJson(Json json) =>
      MediaItemRead(item: MediaItem.fromJson(asJson(json['item'])), cards: asInt(json['cards']));
}

String? _nonEmpty(Object? value) => value is String && value.isNotEmpty ? value : null;
