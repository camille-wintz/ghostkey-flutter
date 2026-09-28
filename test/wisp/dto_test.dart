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
}
