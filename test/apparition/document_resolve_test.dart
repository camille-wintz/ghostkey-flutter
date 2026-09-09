import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/apparition/document_resolve.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary _doc(String id, String filename, {DocumentKind kind = DocumentKind.chapter}) =>
    DocumentSummary(id: id, kind: kind, filename: filename, version: 1, wordCount: 0, updatedAt: '');

ProjectFull _project() => ProjectFull.fromJson({
      'project': {
        'id': 'p',
        'owner_id': 'u',
        'series_id': 's',
        'series_index': 0,
        'name': 'Book',
        'title': '',
        'description': '',
        'author': '',
        'cover_filename': '',
        'saved_prompts': <Map<String, dynamic>>[],
        'active_draft_id': 'd',
        'active_draft_version': 1,
        'created_at': '',
        'updated_at': '',
      },
      'draft': {'id': 'd', 'name': 'Draft', 'version': 1},
      'chapters': [
        _doc('c1', 'one.md').toJson(),
        {
          'name': 'Part',
          'chapters': [_doc('c2', 'two.md').toJson()],
        },
      ],
      'notes': [_doc('n1', 'Note 1.md', kind: DocumentKind.note).toJson()],
      'assets': <Map<String, dynamic>>[],
    });

void main() {
  test('resolves chapters, folder chapters and notes by filename', () {
    final data = _project();
    expect(resolveDocumentId(data, 'one.md'), 'c1');
    expect(resolveDocumentId(data, 'two.md'), 'c2');
    expect(resolveDocumentId(data, 'Note 1.md'), 'n1');
    expect(resolveDocumentId(data, 'missing.md'), isNull);
  });

  test('a recent rename bridges the gap before the refetch', () {
    final data = _project();
    final recent = RecentRename()..note('c2', 'renamed.md');
    expect(resolveDocumentId(data, 'renamed.md', recent), 'c2');
    expect(resolveDocumentId(data, 'other.md', recent), isNull);
  });
}
