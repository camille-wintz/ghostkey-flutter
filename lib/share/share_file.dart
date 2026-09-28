import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ShareOutcome { shared, cancelled }

/// Hand a file the app made to the phone's own share sheet — Messages,
/// WhatsApp, Instagram, mail, Drive. The one owner of "send this out of the
/// app": the caller makes the bytes and says nothing about where they go.
///
/// The file is written to the temp folder first, under [name], because that
/// is the name the receiving app shows. Closing the sheet is an answer, not a
/// failure. The desk's twin is `ghost-key/src/shared/share/shareFile.ts`.
Future<ShareOutcome> shareFile(Uint8List bytes, {required String name, String mimeType = 'image/png'}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  final result = await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)]));
  if (kDebugMode) debugPrint('[share] $name: ${result.status.name}');
  return result.status == ShareResultStatus.dismissed ? ShareOutcome.cancelled : ShareOutcome.shared;
}
