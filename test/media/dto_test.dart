import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';
import 'package:ghostkey/server/dto/media.dart';

Map<String, dynamic> _item({String id = 'i1', String kind = 'image', String? folderId, Map<String, dynamic>? meta}) => {
      'id': id,
      'series_id': 's1',
      'folder_id': folderId,
      'kind': kind,
      'title': 'The mill',
      'body': 'A mill at dusk.',
      'body_chars': 15,
      'asset_id': 'a1',
      'url': null,
      'meta': meta ??
          {'width': 1200, 'height': 800, 'preview_asset_id': 'p1', 'caption_by': 'prompt', 'prompt': 'A mill at dusk.'},
      'origin': 'author',
      'version': 3,
      'created_at': '2026-09-28T10:00:00.000Z',
      'updated_at': '2026-09-28T11:00:00.000Z',
    };

void main() {
  group('MediaItem', () {
    test('reads the whole item, meta included', () {
      final item = MediaItem.fromJson(_item(folderId: 'f1'));
      expect(item.id, 'i1');
      expect(item.seriesId, 's1');
      expect(item.folderId, 'f1');
      expect(item.isImage, isTrue);
      expect(item.assetId, 'a1');
      expect(item.url, isNull);
      expect((item.width, item.height), (1200, 800));
      expect(item.previewAssetId, 'p1');
      expect(item.thumbAssetId, 'p1');
      expect(item.captionBy, 'prompt');
      expect(item.prompt, 'A mill at dusk.');
      expect(item.version, 3);
      expect(item.createdAt, '2026-09-28T10:00:00.000Z');
      expect(item.updatedAt, '2026-09-28T11:00:00.000Z');
    });

    test('an unfiled item with no preview falls back to its asset', () {
      final item = MediaItem.fromJson(_item(meta: {'width': 10, 'height': 10}));
      expect(item.folderId, isNull);
      expect(item.previewAssetId, isNull);
      expect(item.thumbAssetId, 'a1');
      expect(item.captionBy, isNull);
    });

    test('a link keeps its url; a missing meta reads as none', () {
      final link = MediaItem.fromJson({..._item(kind: 'link'), 'url': 'https://example.com', 'meta': null});
      expect(link.url, 'https://example.com');
      expect(link.isImage, isFalse);
      expect(link.width, isNull);
    });
  });

  test('the listing reads items and folders', () {
    final library = MediaLibrary.fromJson({
      'items': [_item(), _item(id: 'i2', kind: 'text')],
      'folders': [
        {
          'id': 'f1',
          'series_id': 's1',
          'name': 'Places',
          'sort_index': 2,
          'created_at': '2026-09-28T10:00:00.000Z',
          'updated_at': '2026-09-28T10:00:00.000Z',
        },
      ],
    });
    expect(library.items.map((i) => i.id), ['i1', 'i2']);
    final folder = library.folders.single;
    expect((folder.id, folder.name, folder.sortIndex, folder.seriesId), ('f1', 'Places', 2, 's1'));
  });

  test('a keyword hit has no score', () {
    final hit = MediaSearchHit.fromJson({'item': _item(), 'score': null, 'snippet': 'mill'});
    expect(hit.item.id, 'i1');
    expect(hit.score, isNull);
    expect(hit.snippet, 'mill');
  });

  test('the single-item read carries the cards count', () {
    final read = MediaItemRead.fromJson({'item': _item(), 'cards': 2});
    expect(read.item.id, 'i1');
    expect(read.cards, 2);
  });

  test('an entity edit reads the pictures it refused', () {
    final written = BibleEntityWriteResponse.fromJson({
      'id': 'e1',
      'rejected': <String>[],
      'refused_images': [
        {'item_id': 'i1', 'reason': 'gallery_full'},
        {'item_id': 'i2', 'reason': 'not_an_image'},
        {'item_id': 'i3', 'reason': 'item_not_found'},
        {'item_id': 'i4', 'reason': 'something_new'},
      ],
      'spellings': <String>[],
      'entities': <Map<String, dynamic>>[],
    });
    expect(written.refusedImages.map((r) => (r.itemId, r.reason)), [
      ('i1', RefusedImageReason.galleryFull),
      ('i2', RefusedImageReason.notAnImage),
      ('i3', RefusedImageReason.itemNotFound),
      ('i4', RefusedImageReason.other),
    ]);
    expect(BibleEntityWriteResponse.fromJson({'id': 'e1', 'entities': <Map<String, dynamic>>[]}).refusedImages, isEmpty);
  });
}
