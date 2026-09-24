import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/plan.dart';

void main() {
  test('a board reads its structure, its roots and each card’s beat', () {
    final map = StoryMap.fromJson({
      'id': 'm1',
      'template_id': 'story_grid',
      'name': null,
      'template_version': 5,
      'source': 'authored',
      'version': 3,
      'generated_at': '2026-09-24T10:00:00Z',
      'nodes': [
        {'id': 'l', 'kind': 'label', 'title': 'Act One', 'description': '', 'chapters': <Object>[], 'cards': <Object>[]},
        {'id': 'c', 'key': 'act_one_inciting_incident', 'title': 'Inciting incident', 'description': '', 'chapters': <Object>[], 'cards': <Object>[]},
      ],
      'layout': {'format_version': 4, 'positions': <String, Object>{}, 'roots': ['c']},
    });
    expect(map.templateId, 'story_grid');
    expect(map.roots, ['c']);
    expect(map.cards.first.isLabel, isTrue);
    expect(map.cards.last.key, 'act_one_inciting_incident');
    expect(boardTitle(map, 'Story Grid'), 'Story Grid');
  });

  test('a board with no layout has no roots, and a blank unnamed one is “Untitled board”', () {
    final map = StoryMap.fromJson({'id': 'm', 'template_id': null, 'name': null, 'source': 'authored', 'nodes': <Object>[], 'layout': null});
    expect(map.roots, isEmpty);
    expect(boardTitle(map, null), 'Untitled board');
  });

  test('a template reads its beats as hints by key', () {
    final t = StoryTemplate.fromJson({
      'id': 't',
      'name': 'Three acts',
      'tradition': 'x',
      'description': 'd',
      'family': 'universal',
      'origin': 'builtin',
      'version': 1,
      'nodes': [
        {
          'key': 'one',
          'title': 'One',
          'beats': [
            {'key': 'hook', 'label': 'Hook', 'hint': 'What grabs?'},
          ],
        },
      ],
    });
    expect(t.hints, {'hook': 'What grabs?'});
  });

  test('an outline row reads its proposal, parts and all, and keeps what it does not know', () {
    final outline = AuthoredOutline.fromJson({
      'text': 'Plan',
      'chapters': [
        {
          'id': 'p1',
          'name': 'Part 1',
          'chapters': [
            {
              'id': 'c1',
              'title': 'One',
              'notes': 'n',
              'words': 2500,
              'origin': 'both',
              'match': {'document_id': 'd1', 'filename': 'One.md', 'words': 900, 'confidence': 'strong', 'reason': 'Same scene'},
              'use_as_reference': true,
              'copy_prose': false,
              'entities': [
                {'name': 'Ada', 'type': 'character'},
              ],
            },
          ],
        },
        {'id': 'c2', 'title': 'Two', 'notes': '', 'origin': 'outline', 'match': null, 'use_as_reference': false, 'copy_prose': false},
      ],
      'matched_draft_id': 'draft-1',
      'broken_at': null,
      'broken_from': {'kind': 'map', 'map_id': 'm1'},
      'committed_draft_id': null,
      'changeset': null,
      'changeset_draft_id': null,
      'changeset_at': null,
      'intent': '',
    });
    expect(outline.pending, isTrue);
    expect(outline.brokenFrom.mapId, 'm1');
    final part = outline.chapters.first as ProposalPart;
    final one = part.chapters.single;
    expect(one.words, 2500);
    expect(one.origin, ProposalOrigin.both);
    expect(one.match!.documentId, 'd1');
    // An edit carries the cast it never read back to the server.
    expect(one.copyWith(title: 'Uno').toJson()['entities'], [
      {'name': 'Ada', 'type': 'character'},
    ]);
    expect(part.toJson()['chapters'], hasLength(1));
    expect(proposalChapters(outline.chapters).map((c) => c.id), ['c1', 'c2']);
  });

  test('an old row with no broken_from reads as made from the prose', () {
    final outline = AuthoredOutline.fromJson({'text': '', 'chapters': <Object>[], 'broken_from': null});
    expect(outline.brokenFrom.isProse, isTrue);
    expect(outline.pending, isFalse);
  });

  test('a changeset reads its ops, skips one it does not know, and folds edits into a write', () {
    final changeset = Changeset.fromJson({
      'summary': 'S',
      'questions': <Object>[],
      'ops': [
        {
          'id': 'o1',
          'op': 'remove',
          'chapters': [
            {'document_id': 'd1', 'filename': 'One.md', 'words': 100},
          ],
          'reason': 'r',
        },
        {
          'id': 'o2',
          'op': 'add',
          'with': [
            {'title': 'New', 'notes': 'n', 'entities': <Object>[], 'from': null},
          ],
          'after': null,
          'folder_id': null,
          'reason': 'r',
        },
        {'id': 'o3', 'op': 'merge', 'reason': 'future'},
        {
          'id': 'o4',
          'op': 'rewrite',
          'chapters': [
            {'document_id': 'd2', 'filename': 'Two.md'},
          ],
          'with': [
            {
              'title': 'Two again',
              'notes': '',
              'entities': <Object>[],
              'from': {'document_id': 'd2', 'filename': 'Two.md'},
            },
          ],
          'reason': 'r',
        },
      ],
      'ledger': {
        'chapters_before': 3,
        'chapters_after': 3,
        'words_before': 1000,
        'words_after': 1100,
        'removed_chapters': 1,
        'rewritten_chapters': 1,
        'written_chapters': 2,
        'characters_leaving': <Object>[],
      },
      'verdict': {'ok': false, 'problems': ['p'], 'attempts': 2},
    });
    expect(changeset.ops.map((o) => o.id), ['o1', 'o2', 'o4']);
    final add = changeset.ops[1] as ChangesetAdd;
    expect(add.after, isNull);
    final edited = add.withWritten([add.written.first.withText(title: 'Renamed')]);
    expect(edited.toJson()['with'][0]['title'], 'Renamed');
    expect(edited.toJson()['folder_id'], isNull);
    expect((changeset.ops[2] as ChangesetRewrite).written.single.from!.documentId, 'd2');
    expect(changeset.verdict!.problems, ['p']);
  });

  test('a commit reads the draft and each chapter’s notes and target', () {
    final result = CommitResult.fromJson({
      'draft': {'id': 'd', 'name': 'Draft from the outline', 'version': 1},
      'drafts': <Object>[],
      'chapters': [
        {'document_id': 'x', 'filename': 'One.md', 'notes': 'n', 'words': 3000},
        {'document_id': 'y', 'filename': 'Two.md', 'notes': '', 'words': null},
      ],
      'cast': {'attached': 0, 'created': 0, 'carried': 0, 'detached': 0},
    });
    expect(result.draftName, 'Draft from the outline');
    expect(result.chapters.first.words, 3000);
    expect(result.chapters.last.words, isNull);
  });
}
