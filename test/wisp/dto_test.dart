import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/jobs.dart';
import 'package:ghostkey/server/dto/wisp.dart';
import 'package:ghostkey/wisp/access.dart';

void main() {
  test('an outline with no cache row reads as empty at every length', () {
    final r = OutlineResult.fromJson({'outline': null, 'central_relationship': null, 'format_version': null, 'synopsis': null, 'extended': null});
    expect(r.chapters, isEmpty);
    expect(r.condensed(OutlineLength.synopsis), isNull);
  });

  test('a condensed outline reads as its prose', () {
    final r = OutlineResult.fromJson({
      'outline': [
        {'chapter': '01.md', 'summary': 'A', 'word_count': 1200},
      ],
      'synopsis': {
        'word_count': 900,
        'text': 'x\n\ny',
      },
      'extended': null,
    });
    expect(r.chapters.single.wordCount, 1200);
    expect(r.synopsis!.text, 'x\n\ny');
  });

  test('a continuity finding reads defensively', () {
    final report = ContinuityReport.fromJson({
      'chapters_analyzed': 12,
      'hard_errors': [
        {'chapter': '03.md', 'kind': 'hard_error', 'category': 'timeline', 'why_not_development': 'because', 'entity': ''},
      ],
      'arc_drift': <Object>[],
    });
    final f = report.hardErrors.single;
    expect(f.hardError, isTrue);
    expect(f.verified, isTrue);
    expect(f.entity, isNull);
    expect(f.explanation, 'because');
    expect(report.extractionFailures, isEmpty);
  });

  test('a continuity preview counts the held-back findings as issues', () {
    final read = ContinuityRead.fromJson({
      'report': {
        'chapters_analyzed': 12,
        'hard_errors': [
          {'chapter': '03.md', 'kind': 'hard_error', 'category': 'timeline'},
        ],
        'arc_drift': <Object>[],
      },
      'preview': {'hidden_words': 420, 'hidden_units': 6},
    });
    expect(read.report!.hardErrors, hasLength(1));
    expect(read.issueCount, 7);
    expect(ContinuityRead.fromJson({'report': null, 'preview': null}).report, isNull);
  });

  test('pacing intensities are clamped to the wave', () {
    final r = AnalysisReport.fromJson({
      'analysis': 'pacing',
      'generated_at': '2026-09-17T00:00:00Z',
      'chapter_count': 1,
      'overview': '',
      'beats': [
        {'chapter': '01.md', 'intensity': 12, 'note': ''},
      ],
    });
    expect(r.beats.single.intensity, 10);
    expect(r.themes, isEmpty);
  });

  test('job questions ride the snapshot, options with their inputs', () {
    final job = JobSnapshot.fromJson({
      'id': 'cq-p',
      'kind': 'continuity',
      'project_id': 'p',
      'label': '',
      'status': 'done',
      'progress': null,
      'questions': [
        {
          'id': 'q1',
          'question': 'Which is the story?',
          'options': [
            {'id': 'prior', 'label': 'Earlier'},
            {'id': 'intentional', 'label': 'Intentional', 'input': {'placeholder': 'Why?'}},
          ],
        },
      ],
    });
    expect(job.questions.single.options.last.inputPlaceholder, 'Why?');
    expect(job.questions.single.options.first.inputPlaceholder, isNull);
  });

  test('each analysis counts on its own counter', () {
    expect(analysisQuotaFeature(AnalysisId.pacing), 'pacing_analysis');
  });

  test('a read with no preview field reads whole', () {
    final read = AnalysisRead.fromJson({
      'report': {'analysis': 'theme', 'generated_at': '', 'chapter_count': 1, 'overview': 'x'},
    });
    expect(read.report!.overview, 'x');
    expect(read.preview, isNull);
    expect(OutlineResult.fromJson({'outline': null, 'synopsis': null, 'extended': null}).previews, isEmpty);
  });

  test('a preview says per part how much was held back', () {
    final read = AnalysisRead.fromJson({
      'report': null,
      'preview': {'hidden_words': 900, 'hidden_units': 5},
    });
    expect(read.preview!.hiddenWords, 900);
    final outline = OutlineResult.fromJson({
      'outline': <Object>[],
      'synopsis': null,
      'extended': null,
      'preview': {
        'outline': {'hidden_words': 4000, 'hidden_units': 23},
        'synopsis': null,
        'extended': {'hidden_words': 3000, 'hidden_units': 12},
      },
    });
    expect(outline.previews[OutlineLength.detailed]!.hiddenUnits, 23);
    expect(outline.previews[OutlineLength.synopsis], isNull);
    expect(outline.previews[OutlineLength.extended]!.hiddenWords, 3000);
  });

  test('a beta read parses without an overview, its letter split into paragraphs', () {
    final read = AnalysisRead.fromJson({
      'report': {
        'format_version': 1,
        'analysis': 'beta_custard',
        'generated_at': '2026-09-29T00:00:00Z',
        'model': 'sonnet-5-5',
        'chapter_count': 12,
        'reader': 'custard',
        'letter': 'I had three suspects.\n\nI was wrong about two.\n \nDelighted.',
        'answers': [
          {'question': 'When did I first suspect?', 'answer': 'Chapter 4.', 'quotes': ['the key was warm']},
        ],
        'chapters': ['04.md', '09.md'],
        'comments': [
          {'chapter': '04.md', 'reaction': 'guessed', 'note': 'The key.', 'quote': null},
          {'chapter': '09.md', 'reaction': 'someday_new', 'note': '', 'quote': 'x'},
        ],
        'put_down': null,
      },
    });
    final r = read.report!;
    expect(r.overview, '');
    expect(r.reader, 'custard');
    expect(r.letterParagraphs, ['I had three suspects.', 'I was wrong about two.', 'Delighted.']);
    expect(r.answers.single.quotes, ['the key was warm']);
    expect(r.chapters, ['04.md', '09.md']);
    expect(r.comments.first.reaction, BetaReaction.guessed);
    expect(r.comments.first.quote, isNull);
    expect(r.comments.last.reaction, BetaReaction.hooked);
    expect(r.putDown, isNull);
    expect(isBetaRead(r.analysis), isTrue);
    expect(isBetaRead(AnalysisId.theme.wire), isFalse);
  });

  test('a beta read preview keeps the first paragraph and nothing else', () {
    final read = AnalysisRead.fromJson({
      'report': {
        'analysis': 'beta_leopold',
        'generated_at': '',
        'chapter_count': 3,
        'letter': 'Right on time.',
        'answers': <Object>[],
        'comments': <Object>[],
        'put_down': {'chapter': '', 'why': ''},
      },
      'preview': {'hidden_words': 900, 'hidden_units': 14},
    });
    expect(read.report!.letterParagraphs, hasLength(1));
    expect(read.report!.putDown, isNull);
    expect(read.preview!.hiddenUnits, 14);
  });

  test("a reader's pages read blocks, placed comments and the held-back count", () {
    final read = BetaReaderPages.fromJson({
      'book': {
        'pages': [
          {
            'chapter': '01 The Lighthouse.md',
            'blocks': [
              {'kind': 'heading', 'text': 'The Lighthouse'},
              {'kind': 'paragraph', 'text': 'The lamp was out.'},
              {'kind': 'break', 'text': ''},
              {'kind': 'paragraph', 'text': 'Morning.', 'continued': true},
            ],
          },
        ],
        'comments': [
          {
            'chapter': '01 The Lighthouse.md',
            'reaction': 'hooked',
            'note': 'Why is it out?',
            'quote': 'The lamp was out.',
            'page': 0,
            'at': {'block': 1, 'from': 0, 'to': 17},
          },
          {'chapter': '01 The Lighthouse.md', 'reaction': 'moved', 'note': 'Whole chapter.', 'quote': null, 'page': 0, 'at': null},
        ],
        'unplaced': 2,
      },
      'hidden_comments': 5,
    });
    final book = read.book!;
    expect(book.pages.single.blocks.map((b) => b.kind), [
      PageBlockKind.heading,
      PageBlockKind.paragraph,
      PageBlockKind.sceneBreak,
      PageBlockKind.paragraph,
    ]);
    expect(book.pages.single.blocks.last.continued, isTrue);
    expect(book.pages.single.blocks[1].continued, isFalse);
    expect(book.comments.first.at, (block: 1, from: 0, to: 17));
    expect(book.comments.last.at, isNull);
    expect(book.comments.last.reaction, BetaReaction.moved);
    expect(book.unplaced, 2);
    expect(read.hiddenComments, 5);
    expect(BetaReaderPages.fromJson({'book': null, 'hidden_comments': 0}).book, isNull);
  });

  test('the beta readers catalogue reads each card', () {
    final readers = ReaderCard.listFromJson({
      'readers': [
        {
          'id': 'dozy',
          'analysis': 'beta_dozy',
          'name': 'Dozy',
          'genres': 'Epic fantasy',
          'description': 'Reads until 3 a.m.',
          'picture': '<svg/>',
          'has_letter': true,
        },
      ],
    });
    expect(readers.single.analysis, 'beta_dozy');
    expect(readers.single.hasLetter, isTrue);
  });
}
