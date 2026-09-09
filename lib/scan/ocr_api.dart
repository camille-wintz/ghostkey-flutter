import '../server/client.dart';
import '../server/dto/json.dart';

// Photo-to-text OCR runs server-side (`POST /api/ocr` in openapi.yaml): the
// Anthropic key lives only on ghostkey-server, which proxies the image to
// Claude vision and returns the text. Capture and encoding happen on-device
// (see fit_image.dart / the viewfinder); this only ships the encoded image up.
//
// `projectId` has the server inject that project's world-bible spellings into
// the vision prompt so handwritten names transcribe canonically — best-effort
// on the server's side: an absent or foreign id means no spellings, never an
// error.

Future<String> ocrImage({
  required String base64,
  required String mimeType,
  String? projectId,
}) async {
  final res = await apiFetch(
    '/api/ocr',
    method: 'POST',
    body: {
      'image_base64': base64,
      'media_type': mimeType,
      'project_id': ?projectId,
    },
  );
  return asString(res.jsonObject()['text']).trim();
}
