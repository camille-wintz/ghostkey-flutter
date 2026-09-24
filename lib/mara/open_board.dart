import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

// Which board Cards is on, per book, on this phone. Device state: the next
// visit lands where the author was, and going back to the picker forgets it —
// the picker is where they are then. A file, because it outlives the process.

Future<File> _file() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/mara-open-boards.json');
}

Future<Map<String, dynamic>> _read() async {
  final file = await _file();
  if (!await file.exists()) return {};
  final parsed = jsonDecode(await file.readAsString());
  return parsed is Map<String, dynamic> ? parsed : {};
}

/// The open board's id for a book, or null for the picker.
class OpenBoard extends AsyncNotifier<String?> {
  OpenBoard(this.projectId);
  final String projectId;

  @override
  Future<String?> build() async {
    try {
      final stored = (await _read())[projectId];
      return stored is String ? stored : null;
    } catch (e) {
      debugPrint('[mara] could not read the open boards: $e');
      return null;
    }
  }

  void open(String mapId) => _remember(mapId);

  void close() => _remember(null);

  void _remember(String? mapId) {
    state = AsyncData(mapId);
    _write(mapId);
  }

  Future<void> _write(String? mapId) async {
    try {
      final all = await _read().catchError((_) => <String, dynamic>{});
      if (mapId == null) {
        all.remove(projectId);
      } else {
        all[projectId] = mapId;
      }
      await (await _file()).writeAsString(jsonEncode(all));
    } catch (e) {
      debugPrint('[mara] could not remember the open board: $e');
    }
  }
}

final openBoardProvider = AsyncNotifierProvider.family<OpenBoard, String?, String>(OpenBoard.new);
