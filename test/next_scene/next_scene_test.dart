import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/next_scene.dart';

void main() {
  test('reads each kind the contract names', () {
    NextScene read(String kind) => NextScene.fromJson({
          'kind': kind,
          'spot': 'unwritten:abc',
          'document_id': 'abc',
          'chapter': 'Chapter 2',
          'headline': 'Chapter 2 is waiting',
          'prompt': 'What does Mara find upstairs?',
        });
    expect(read('unwritten').kind, NextSceneKind.unwritten);
    expect(read('transition').kind, NextSceneKind.transition);
    expect(read('continue').kind, NextSceneKind.continue_);
    expect(read('unwritten').documentId, 'abc');
  });
}
