import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/wisp/report_preview.dart';
import 'package:ghostkey/server/dto/billing.dart';
import 'package:ghostkey/server/dto/wisp.dart';
import 'package:ghostkey/server/providers.dart';
import 'package:ghostkey/wisp/preview_filler.dart';

int wordCount(List<String> paras) => paras.fold(0, (n, p) => n + p.split(' ').length);

void main() {
  group('previewFiller', () {
    test('sizes the filler from the hidden words, capped', () {
      final big = previewFiller(const PreviewCut(hiddenWords: 5000, hiddenUnits: 30));
      expect(wordCount(big), previewFillerMaxWords);
      expect(big.length, 8);
      final small = previewFiller(const PreviewCut(hiddenWords: 150, hiddenUnits: 3));
      expect(wordCount(small), 150);
      expect(small.length, 3);
    });

    test('keeps a floor under a tiny cut, and never splits it into slivers', () {
      final tiny = previewFiller(const PreviewCut(hiddenWords: 4, hiddenUnits: 9));
      expect(wordCount(tiny), 60);
      expect(tiny.length, 2);
    });

    test('the same cut gives the same filler', () {
      const cut = PreviewCut(hiddenWords: 321, hiddenUnits: 4);
      expect(previewFiller(cut), previewFiller(cut));
    });
  });

  testWidgets('the preview lays out at phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accessProvider.overrideWith((ref) async => const AccessSnapshot(plan: Plan.free, capabilities: [])),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportPreview(cut: PreviewCut(hiddenWords: 2, hiddenUnits: 1), subject: 'extended outline'),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('SEE THE WHOLE EXTENDED OUTLINE'), findsOneWidget);
  });
}
