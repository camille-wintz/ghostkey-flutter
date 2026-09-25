import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/media.dart';

void main() {
  group('ChatTurnResult.fromJson', () {
    test('reads the answering model and the one it stood in for', () {
      final r = ChatTurnResult.fromJson({'answer': 'Hi', 'model': 'opus-5-5', 'switched_from': 'deepseek'});
      expect(r.model, 'opus-5-5');
      expect(r.switchedFrom, 'deepseek');
    });

    test('reads nothing switched from a null, and tolerates an older server', () {
      expect(ChatTurnResult.fromJson({'answer': '', 'model': 'auto', 'switched_from': null}).switchedFrom, isNull);
      final old = ChatTurnResult.fromJson({'answer': ''});
      expect(old.model, isNull);
      expect(old.switchedFrom, isNull);
    });
  });

  group('ChatView.fromJson', () {
    test('reads a picture view by its item id', () {
      final view = ChatView.fromJson({'kind': 'image', 'id': 'item-1', 'title': 'The mill'})!;
      expect(view.kind, ChatViewKind.image);
      expect(view.id, 'item-1');
    });

    test('reads a kind it does not know as nothing open', () {
      expect(ChatView.fromJson({'kind': 'hologram', 'id': 'x'}), isNull);
    });
  });

  test('MediaItem reads its series, asset and preview', () {
    final item = MediaItem.fromJson({
      'id': 'i',
      'series_id': 's',
      'kind': 'image',
      'title': 'The mill',
      'body': 'A mill at dusk.',
      'body_chars': 15,
      'asset_id': 'a',
      'meta': {'width': 800, 'height': 600, 'preview_asset_id': 'p'},
      'origin': 'author',
    });
    expect((item.seriesId, item.assetId, item.previewAssetId, item.isImage), ('s', 'a', 'p', true));
    expect(MediaItem.fromJson({'id': 'i', 'kind': 'text', 'asset_id': null, 'meta': <String, dynamic>{}}).assetId, isNull);
  });
}
