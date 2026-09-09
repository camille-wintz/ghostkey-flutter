import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/autosave/draft_journal.dart';

void main() {
  late Directory root;
  late DraftJournal journal;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ghostkey-drafts');
    journal = DraftJournal(root: () async => Directory('${root.path}/drafts'));
  });

  tearDown(() => root.delete(recursive: true));

  test('round-trips a draft and deletes it', () async {
    const draft = DocumentDraft(content: 'text', baseVersion: 3, savedAt: 42);
    await journal.write('p', 'd', draft);
    final read = await journal.read('p', 'd');
    expect(read?.content, 'text');
    expect(read?.baseVersion, 3);
    expect(read?.savedAt, 42);
    await journal.delete('p', 'd');
    expect(await journal.read('p', 'd'), isNull);
  });

  test('a missing or malformed file reads as no draft', () async {
    expect(await journal.read('p', 'none'), isNull);
    final file = File('${root.path}/drafts/p_bad.json');
    await file.parent.create(recursive: true);
    await file.writeAsString('{"content": 5}');
    expect(await journal.read('p', 'bad'), isNull);
    await journal.delete('p', 'missing'); // no throw
  });
}
