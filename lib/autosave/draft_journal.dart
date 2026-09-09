import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// On-disk safety net under the autosave loop. A draft file exists only while a
// document has edits the server hasn't confirmed: it is written (debounced)
// while dirty and deleted the moment a flush lands, so on a process kill the
// unflushed text survives to the next launch. `baseVersion` records the server
// content revision the draft was typed against — restore only applies when the
// server still holds that revision, because a bump means another client wrote
// in between and last-write-wins says the server wins.

class DocumentDraft {
  const DocumentDraft({required this.content, required this.baseVersion, required this.savedAt});
  final String content;
  final int baseVersion;

  /// Milliseconds since the epoch.
  final int savedAt;

  Map<String, dynamic> toJson() => {'content': content, 'baseVersion': baseVersion, 'savedAt': savedAt};

  static DocumentDraft? fromJson(dynamic json) {
    if (json is! Map) return null;
    final content = json['content'];
    final baseVersion = json['baseVersion'];
    if (content is! String || baseVersion is! int) return null;
    final savedAt = json['savedAt'];
    return DocumentDraft(content: content, baseVersion: baseVersion, savedAt: savedAt is int ? savedAt : 0);
  }
}

/// `<documents dir>/drafts/<projectId>_<documentId>.json`. The root is
/// injectable so a test can point it at a temp directory.
class DraftJournal {
  DraftJournal({Future<Directory> Function()? root}) : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}drafts');

  Future<File> _file(String projectId, String documentId) async {
    final dir = await _root();
    return File('${dir.path}${Platform.pathSeparator}${projectId}_$documentId.json');
  }

  Future<void> write(String projectId, String documentId, DocumentDraft draft) async {
    try {
      final file = await _file(projectId, documentId);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
    } catch (e) {
      // Best-effort — the interval flush is still running; losing the journal
      // only narrows the crash window back to what it was before.
      debugPrint('[autosave] draft journal write failed: $e');
    }
  }

  Future<DocumentDraft?> read(String projectId, String documentId) async {
    try {
      final file = await _file(projectId, documentId);
      if (!await file.exists()) return null;
      return DocumentDraft.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      debugPrint('[autosave] draft journal read failed: $e');
      return null;
    }
  }

  Future<void> delete(String projectId, String documentId) async {
    try {
      final file = await _file(projectId, documentId);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[autosave] draft journal delete failed: $e');
    }
  }
}
