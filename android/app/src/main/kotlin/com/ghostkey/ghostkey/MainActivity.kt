package com.ghostkey.ghostkey

import com.ghostkey.ghostkey.recorder.RecorderPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // The dictation recorder (kotlin/…/recorder/): `ghostkey/recorder` +
    // `ghostkey/recorder/events`. An in-app plugin, not a pub package.
    flutterEngine.plugins.add(RecorderPlugin())
  }
}
