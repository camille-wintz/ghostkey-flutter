import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';

void main() {
  test('BibleEntity reads its portrait item and gallery', () {
    final entity = BibleEntity.fromJson({
      'id': 'e',
      'key': 'mara',
      'name': 'Mara',
      'image_item_id': 'item-0',
      'image_asset_id': 'asset-0',
      'images': [
        {
          'id': 'g1',
          'item_id': 'item-1',
          'asset_id': 'asset-1',
          'preview_asset_id': 'prev-1',
          'width': 1200,
          'height': 600,
          'title': 'The mill',
          'caption': 'At dusk.',
        },
        {'id': 'g2', 'item_id': 'item-2', 'asset_id': 'asset-2', 'preview_asset_id': null, 'width': null, 'height': null, 'title': '', 'caption': ''},
      ],
    });
    expect(entity.imageItemId, 'item-0');
    expect(entity.imageAssetId, 'asset-0');
    expect(entity.images.map((i) => i.thumbAssetId), ['prev-1', 'asset-2']);
    expect(entity.images.first.aspectRatio, 2);
    expect(entity.images.last.aspectRatio, isNull);
  });

  test('a card from an older server has an empty gallery', () {
    expect(BibleEntity.fromJson({'id': 'e', 'key': 'k', 'name': 'N'}).images, isEmpty);
  });
}
