import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';
import 'package:ghostkey/veil/gmc_draft.dart';

void main() {
  GmcDraft draft() => GmcDraft(
        authored: {'External goal': 'Keep the light lit'},
        glance: const [
          DossierGlanceItem(label: 'External goal', value: 'Hold the tower'),
          DossierGlanceItem(label: 'Internal goal', value: ' Be forgiven '),
        ],
      );

  test('opens clean, with every cell and the dossier as suggestions', () {
    final gmc = draft();
    expect(GmcDraft.labels, hasLength(10));
    expect(gmc.field('External goal').text, 'Keep the light lit');
    expect(gmc.suggestion('Internal goal'), 'Be forgiven');
    expect(gmc.dirty, isFalse);
    gmc.dispose();
  });

  test('only changed cells are written, an emptied one as a clear', () {
    final gmc = draft();
    gmc.field('External goal').text = '';
    gmc.field('Internal arc').text = ' Learns to leave ';
    expect(gmc.changed, {'External goal': '', 'Internal arc': 'Learns to leave'});
    gmc.dispose();
  });

  test("fill copies the dossier's answer into empty cells only", () {
    final gmc = draft();
    expect(gmc.canFill, isTrue);
    gmc.fill();
    expect(gmc.field('External goal').text, 'Keep the light lit');
    expect(gmc.changed, {'Internal goal': 'Be forgiven'});
    expect(gmc.canFill, isFalse);
    gmc.dispose();
  });
}
