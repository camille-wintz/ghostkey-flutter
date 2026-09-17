import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../server/dto/json.dart';
import '../server/errors.dart';
import '../server/tokens.dart';

// The offline mirror — the ONE owner of offline project data on the phone:
// the shelf (folders, project lists), each project's detail (its chapter
// tree), and each document's last server copy. Nothing else is mirrored; the
// other rooms stay cloud-only and say so when the server can't be reached.
//
// The server stays the truth. A mirrored read goes to the network first and
// keeps what the server answered; the held copy is served only when the
// request could not reach the server at all. So online, the app never shows
// anything the server did not just say.
//
// Unsaved words are NOT here: they live in the autosave's draft journal,
// which restores them over the copy served from here when the base version
// still matches. The mirror only has to make the document openable.
//
// Lifecycle: namespaced by user; wiped on sign-out, and wiped whole on the
// first launch after the app was installed or updated, so no build ever reads
// a copy an older build wrote.

/// How long a mirrored read waits for the server before serving the held
/// copy. Airplane mode fails at once; this is for a connection that hangs.
const Duration mirroredReadTimeout = Duration(seconds: 15);

class _Held {
  const _Held(this.json, this.version);
  final Json json;
  final int? version;
}

class Mirror {
  Mirror({Future<Directory> Function()? root, Future<String> Function()? buildStamp, String? Function()? userId})
      : _root = root ?? _defaultRoot,
        _buildStamp = buildStamp ?? _installedBuildStamp,
        _userId = userId ?? getUserId;

  final Future<Directory> Function() _root;
  final Future<String> Function() _buildStamp;
  final String? Function() _userId;

  Future<Directory>? _ready;

  /// Writes and wipes, in order: a GET's write landing after a sign-out's
  /// wipe would put the last account's book back.
  Future<void> _ops = Future.value();

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}mirror');

  /// Changes on every install and every update of the app, rebuilds of the
  /// same version included.
  static Future<String> _installedBuildStamp() async {
    final info = await PackageInfo.fromPlatform();
    final updated = info.updateTime ?? info.installTime;
    return '${info.version}+${info.buildNumber}@${updated?.millisecondsSinceEpoch ?? 0}';
  }

  Future<Directory> _dir() => _ready ??= _open();

  Future<Directory> _open() async {
    final root = await _root();
    final stamp = await _buildStamp();
    final stampFile = File('${root.path}${Platform.pathSeparator}build');
    try {
      final held = await stampFile.exists() ? await stampFile.readAsString() : null;
      if (held != stamp) {
        if (await root.exists()) await root.delete(recursive: true);
        await root.create(recursive: true);
        await stampFile.writeAsString(stamp, flush: true);
        if (kDebugMode) debugPrint('[mirror] New build ($stamp) — offline copies cleared');
      }
    } catch (e) {
      debugPrint('[mirror] build check failed: $e');
    }
    return root;
  }

  Future<File?> _file(String key) async {
    final uid = _userId();
    if (uid == null) return null;
    final root = await _dir();
    final sep = Platform.pathSeparator;
    return File('${root.path}$sep$uid$sep${Uri.encodeComponent(key)}.json');
  }

  /// The server's answer to [fetch], kept under [key]; the kept copy when the
  /// server can't be reached. [version] reads the answer's revision, when it
  /// has one, so a late response never replaces a newer copy.
  Future<Json> readThrough(String key, Future<Json> Function() fetch, {int? Function(Json json)? version}) async {
    final Json json;
    try {
      json = await fetch();
    } on ServerError catch (e) {
      if (e.code != 'network_error') rethrow;
      final held = await _read(key);
      if (held == null) rethrow;
      if (kDebugMode) debugPrint('[mirror] Offline — serving the held copy of $key');
      return held.json;
    }
    await remember(key, json, version: version?.call(json));
    return json;
  }

  /// Keep a server answer that did not come through [readThrough] — a write's
  /// response, which is the newest copy there is.
  Future<void> remember(String key, Json json, {int? version}) {
    final file = _file(key);
    return _ops = _ops.then((_) async {
      try {
        final target = await file;
        if (target == null) return;
        if (version != null) {
          final held = await _readFile(target);
          final heldVersion = held?.version;
          if (heldVersion != null && heldVersion > version) return;
        }
        await target.parent.create(recursive: true);
        final temp = File('${target.path}.tmp');
        await temp.writeAsString(jsonEncode({'version': version, 'json': json}), flush: true);
        await temp.rename(target.path);
      } catch (e) {
        // Best-effort: a missed write costs this copy offline, nothing online.
        debugPrint('[mirror] write failed for $key: $e');
      }
    });
  }

  /// Every account's copies. Sign-out.
  Future<void> wipe() => _ops = _ops.then((_) async {
        try {
          final root = await _dir();
          await for (final entry in root.list()) {
            if (entry is Directory) await entry.delete(recursive: true);
          }
        } catch (e) {
          debugPrint('[mirror] wipe failed: $e');
        }
      });

  Future<_Held?> _read(String key) async {
    await _ops;
    final file = await _file(key);
    return file == null ? null : _readFile(file);
  }

  Future<_Held?> _readFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['json'] is! Map) return null;
      final version = data['version'];
      return _Held(asJson(data['json']), version is int ? version : null);
    } catch (e) {
      debugPrint('[mirror] read failed for ${file.path}: $e');
      return null;
    }
  }
}

/// The app's one mirror.
final Mirror mirror = Mirror();
