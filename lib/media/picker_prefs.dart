import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// The picker's two per-device picks: the tab the author last tapped (every
// picker, every book), and the folder the grid was on, per book. Device
// state, so a file, beside Mara's open boards; the desk keeps the same two
// in localStorage (`useLibraryTab`, `useLibraryView`).

enum LibraryTab { library, draw }

Future<File> _file() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/media-library.json');
}

Future<Map<String, dynamic>> _read() async {
  final file = await _file();
  if (!await file.exists()) return {};
  final parsed = jsonDecode(await file.readAsString());
  return parsed is Map<String, dynamic> ? parsed : {};
}

Future<void> _update(void Function(Map<String, dynamic> all) change) async {
  try {
    final all = await _read().catchError((_) => <String, dynamic>{});
    change(all);
    await (await _file()).writeAsString(jsonEncode(all));
  } catch (e) {
    debugPrint('[media] could not remember the picker\'s place: $e');
  }
}

/// What the device remembers, read once as a picker opens. Nothing on a
/// failed read: the picker opens on its defaults.
Future<({LibraryTab? tab, String? folder})> readPickerPlace(String projectId) async {
  try {
    final all = await _read();
    final tab = LibraryTab.values.where((t) => t.name == all['tab']).firstOrNull;
    final folders = all['folders'];
    final folder = folders is Map ? folders[projectId] : null;
    return (tab: tab, folder: folder is String ? folder : null);
  } catch (e) {
    debugPrint('[media] could not read the picker\'s place: $e');
    return (tab: null, folder: null);
  }
}

/// Only a tap on a tab writes this: a finished draw or an upload moving the
/// author to the library is the picker's doing, not a choice.
Future<void> rememberPickedTab(LibraryTab tab) => _update((all) => all['tab'] = tab.name);

Future<void> rememberFolder(String projectId, String wire) => _update((all) {
      final folders = all['folders'] is Map<String, dynamic> ? all['folders'] as Map<String, dynamic> : <String, dynamic>{};
      folders[projectId] = wire;
      all['folders'] = folders;
    });
