import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/autosave/autosave.dart';
import 'package:ghostkey/autosave/draft_journal.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentDto _doc(String content, int version) => DocumentDto(
      summary: DocumentSummary(id: 'd', kind: DocumentKind.chapter, filename: 'one.md', version: version, wordCount: 0, updatedAt: ''),
      projectId: 'p',
      content: content,
      createdAt: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late DraftJournal journal;
  late TextEditingController text;
  late List<String> saves;
  late List<String> restored;
  var version = 1;

  Autosave make({Completer<void>? gate}) => Autosave(
        projectId: 'p',
        documentId: 'd',
        text: text,
        journal: journal,
        onSaved: (_) {},
        onRestore: (content) {
          restored.add(content);
          text.text = content;
        },
        save: (pid, did, content) async {
          if (gate != null) await gate.future;
          saves.add(content);
          return _doc(content, ++version);
        },
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('ghostkey-autosave');
    journal = DraftJournal(root: () async => root);
    text = TextEditingController();
    saves = [];
    restored = [];
    version = 1;
  });

  tearDown(() {
    text.dispose();
    root.deleteSync(recursive: true);
  });

  test('clean text never saves; dirty text flushes once and the tick returns', () async {
    final gate = Completer<void>();
    text.text = 'base';
    final autosave = make(gate: gate)..loaded(_doc('base', 1));
    await Future<void>.delayed(Duration.zero);
    expect(autosave.saved.value, isTrue);
    autosave.flush();
    expect(saves, isEmpty);

    text.text = 'base typed';
    expect(autosave.saved.value, isFalse);
    autosave.flush();
    autosave.flush(); // the same text in flight is not sent twice
    expect(autosave.saving.value, isTrue);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(saves, ['base typed']);
    expect(autosave.saving.value, isFalse);
    expect(autosave.saved.value, isTrue);
    autosave.dispose();
  });

  test('a draft typed against the server version is restored; a stale one is deleted', () async {
    await journal.write('p', 'd', const DocumentDraft(content: 'base and more', baseVersion: 1, savedAt: 0));
    text.text = 'base';
    final autosave = make()..loaded(_doc('base', 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(restored, ['base and more']);
    autosave.dispose();

    await journal.write('p', 'd', const DocumentDraft(content: 'old', baseVersion: 1, savedAt: 0));
    text.text = 'base';
    restored.clear();
    final second = make()..loaded(_doc('base', 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(restored, isEmpty);
    expect(await journal.read('p', 'd'), isNull);
    second.dispose();
  });

  test('dispose flushes what is dirty', () async {
    text.text = 'base';
    final autosave = make()..loaded(_doc('base', 1));
    text.text = 'base edited';
    autosave.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(saves, ['base edited']);
  });

  test('going to the background journals the dirty text', () async {
    text.text = 'base';
    final autosave = make()..loaded(_doc('base', 1));
    text.text = 'base edited';
    autosave.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // The flush landed and deleted the journal it had just written.
    expect(saves, ['base edited']);
    expect(await journal.read('p', 'd'), isNull);
    autosave.dispose();
  });
}
