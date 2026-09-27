import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/veil/dossier_title.dart';

void main() {
  group('insertDossierTitle', () {
    test('opens an empty text with the title and no blank line above', () {
      final next = insertDossierTitle('', 0);
      expect(next.text, '## ');
      expect(next.caret, 3);
    });

    test('at the end of a paragraph, starts a new block below it', () {
      final next = insertDossierTitle('She keeps the light.', 20);
      expect(next.text, 'She keeps the light.\n\n## ');
      expect(next.caret, next.text.length);
    });

    test('after one newline, adds only the second', () {
      expect(insertDossierTitle('Line\n', 5).text, 'Line\n\n## ');
    });

    test('after a blank line, adds none', () {
      expect(insertDossierTitle('Line\n\n', 6).text, 'Line\n\n## ');
    });

    test('mid-paragraph, splits it and leaves a blank line below the title', () {
      final next = insertDossierTitle('Before after', 7);
      expect(next.text, 'Before\n\n## \n\nafter');
      expect(next.caret, 'Before\n\n## '.length);
    });

    test('drops trailing spaces before the caret', () {
      expect(insertDossierTitle('Words   ', 8).text, 'Words\n\n## ');
    });

    test('keeps the newline that already follows', () {
      expect(insertDossierTitle('One\n\nTwo', 3).text, 'One\n\n## \n\nTwo');
    });
  });
}
