import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// The two welcome-week notices' memory — "I just signed up" and "I have been
// told the week ended". Kept on the device, not on the account: both are
// facts about what this screen has shown.
//
// The arrival lives in memory: the signup and the screen that greets it are
// one process. The ended flag has to outlive the process, so it is a file.

bool _arrival = false;

/// Called from the signup success. The greeting is gated on this AND a live
/// welcome grant, so a deployment running no welcome week says nothing.
void rememberSignupArrival() => _arrival = true;

/// Read and clear. Clearing on read keeps the greeting to one appearance.
bool takeSignupArrival() {
  final arrived = _arrival;
  _arrival = false;
  return arrived;
}

/// Dropped on sign-out: the next account to sign in is not the one that just
/// arrived.
void clearSignupArrival() => _arrival = false;

Future<File> _seenFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/welcome-ended.json');
}

String _key(String account) => account.toLowerCase();

Future<Map<String, dynamic>> _readSeen() async {
  final file = await _seenFile();
  if (!await file.exists()) return {};
  final parsed = jsonDecode(await file.readAsString());
  return parsed is Map<String, dynamic> ? parsed : {};
}

/// Unreadable storage reads as "seen": a notice that cannot be remembered
/// would otherwise return on every launch.
Future<bool> hasSeenWeekEnded(String account) async {
  try {
    return (await _readSeen()).containsKey(_key(account));
  } catch (e) {
    debugPrint('[welcomeNotices] could not read the ended flags: $e');
    return true;
  }
}

Future<void> markWeekEndedSeen(String account) async {
  try {
    final seen = await _readSeen().catchError((_) => <String, dynamic>{});
    seen[_key(account)] = DateTime.now().millisecondsSinceEpoch;
    await (await _seenFile()).writeAsString(jsonEncode(seen));
  } catch (e) {
    debugPrint('[welcomeNotices] could not store the ended flag: $e');
  }
}
