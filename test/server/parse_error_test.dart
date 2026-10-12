import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/client.dart';
import 'package:ghostkey/server/errors.dart';
import 'package:http/http.dart' as http;

Future<ServerError> _parse(int status, Object body) => parseServerError(
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status),
      Uri.parse('https://example.test/api/projects/p1/import-manuscript'),
      'rid',
    );

void main() {
  test('a failed import carries where its file went', () async {
    final error = await _parse(400, {
      'error': 'unsupported_format',
      'chat_handoff': {'item_id': 'i9', 'title': 'chat.json', 'project_id': 'p1'},
    });
    expect(error.code, 'unsupported_format');
    expect(error.status, 400);
    expect((error.chatHandoff?.itemId, error.chatHandoff?.projectId), ('i9', 'p1'));
  });

  test('a failed import the library could not read either carries none', () async {
    final error = await _parse(400, {'error': 'no_text'});
    expect(error.code, 'no_text');
    expect(error.chatHandoff, isNull);
  });
}
