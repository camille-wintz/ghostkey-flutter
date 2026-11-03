import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/batch.dart';

void main() {
  test('a batch reads its standing and what each item left', () {
    final page = BatchPage.fromJson({
      'batch': {'id': 'b', 'label': 'Line edit', 'applies': true, 'status': 'paused', 'pause_reason': 'credits', 'job_id': 'j'},
      'counts': {'total': 3, 'done': 1, 'skipped': 0, 'failed': 1, 'pending': 1},
      'items': [
        {
          'seq': 0,
          'subject': 'c1',
          'label': 'One',
          'status': 'done',
          'outcome': {
            'summary': '2 changes.',
            'open': [
              {'quote': 'q', 'note': 'n'}
            ],
            'undo': {'documentId': 'c1', 'versionId': 'v'}
          }
        },
        {'seq': 1, 'subject': 'c2', 'label': 'Two', 'status': 'failed', 'outcome': null, 'error': 'upstream_error'},
        {'seq': 2, 'subject': 'c3', 'label': 'Three', 'status': 'pending', 'outcome': null},
      ],
      'next': null,
    });
    expect(page.status, BatchStatus.paused);
    expect(page.live, isFalse);
    expect(page.applies, isTrue);
    expect(page.finished, 2);
    expect(page.items[0].canUndo, isTrue);
    expect(page.items[0].open.single.note, 'n');
    expect(page.items[2].waiting, isTrue);
  });

  test('a status this build does not know reads as unknown', () {
    expect(BatchStatus.fromWire('archived'), BatchStatus.unknown);
  });

  test('put back, a chapter offers no undo', () {
    final item = BatchItem.fromJson({
      'seq': 0,
      'subject': 'c',
      'label': 'L',
      'status': 'done',
      'outcome': {'summary': 's', 'undo': {'documentId': 'c', 'versionId': 'v'}, 'undone': true},
    });
    expect(item.canUndo, isFalse);
    expect(item.undone, isTrue);
  });
}
