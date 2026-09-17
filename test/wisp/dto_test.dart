import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/jobs.dart';
import 'package:ghostkey/server/dto/wisp.dart';
import 'package:ghostkey/wisp/access.dart';
import 'package:ghostkey/server/dto/billing.dart';

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

  test('free counts the three analyses on one pooled counter', () {
    QuotaSnapshot snapshot(List<String> features) => QuotaSnapshot.fromJson({
          'plan': 'free',
          'period_end': '2026-09-20T00:00:00Z',
          'features': [
            for (final f in features) {'feature': f, 'label': f, 'allowance': 1, 'used': 0, 'remaining': 1},
          ],
        });
    expect(analysisQuotaFeature(snapshot(['book_analysis']), AnalysisId.theme), 'book_analysis');
    expect(analysisQuotaFeature(snapshot(['pacing_analysis']), AnalysisId.pacing), 'pacing_analysis');
  });
}
