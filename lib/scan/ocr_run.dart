import 'package:flutter/foundation.dart';

import 'fit_image.dart';
import 'ocr_api.dart';

/// One OCR pass over a captured page — the RN `useOcr` hook as a notifier.
/// Capture is owned by the caller; this only runs the request and holds its
/// outcome. A second `run` while one is in flight is ignored.
class OcrRun extends ChangeNotifier {
  String? text;
  bool busy = false;
  Object? error;
  bool _disposed = false;

  Future<void> run(EncodedImage image, {String? projectId}) async {
    if (busy) return;
    busy = true;
    error = null;
    text = null;
    notifyListeners();
    try {
      final result = await ocrImage(base64: image.base64, mimeType: image.mimeType, projectId: projectId);
      if (_disposed) return;
      text = result;
    } catch (e) {
      if (_disposed) return;
      error = e;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
