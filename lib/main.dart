import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'dictation/dictation_flow.dart';
import 'dictation/orphan_sweep.dart';
import 'editor/capture_launchers.dart';
import 'scan/scan_flow.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // The two capture verbs the editor offers, wired here so the editor never
  // imports the recorder or the camera.
  CaptureLaunchers.dictate = startDictation;
  CaptureLaunchers.scan = startScan;
  // Chunk files a killed session left in the cache.
  unawaited(sweepOrphanedRecordings());

  runApp(const ProviderScope(child: GhostkeyApp()));
}
