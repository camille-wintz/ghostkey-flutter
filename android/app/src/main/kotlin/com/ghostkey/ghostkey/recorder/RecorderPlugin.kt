package com.ghostkey.ghostkey.recorder

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * The Dart-facing surface of the recorder: `ghostkey/recorder` (methods) and
 * `ghostkey/recorder/events` (the event stream). See README.md in this
 * directory for the contract. Registered from MainActivity.
 */
class RecorderPlugin :
  FlutterPlugin,
  ActivityAware,
  MethodChannel.MethodCallHandler,
  EventChannel.StreamHandler,
  PluginRegistry.RequestPermissionsResultListener {

  private lateinit var context: Context
  private var methods: MethodChannel? = null
  private var events: EventChannel? = null
  private var activity: Activity? = null
  private var binding: ActivityPluginBinding? = null
  private val permissionResults = HashMap<Int, MethodChannel.Result>()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methods = MethodChannel(binding.binaryMessenger, METHODS).also { it.setMethodCallHandler(this) }
    events = EventChannel(binding.binaryMessenger, EVENTS).also { it.setStreamHandler(this) }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methods?.setMethodCallHandler(null)
    events?.setStreamHandler(null)
    methods = null
    events = null
    RecorderBus.listener = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    this.binding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() = detachActivity()
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
  override fun onDetachedFromActivity() = detachActivity()

  private fun detachActivity() {
    binding?.removeRequestPermissionsResultListener(this)
    binding = null
    activity = null
  }

  // ── Methods ───────────────────────────────────────────────────────────────

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "permissions" -> result.success(
        mapOf(
          "sdk" to Build.VERSION.SDK_INT,
          "microphone" to granted(Manifest.permission.RECORD_AUDIO),
          "notifications" to notificationsGranted(),
        ),
      )
      "requestMicrophone" -> request(Manifest.permission.RECORD_AUDIO, REQ_MIC, result)
      "requestNotifications" -> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
          result.success(true)
        } else {
          request(Manifest.permission.POST_NOTIFICATIONS, REQ_NOTIFICATIONS, result)
        }
      }
      "chunkDirectory" -> result.success(chunkDir().absolutePath)
      "start" -> start(call, result)
      "cut" -> result.success(DictationService.instance?.cut())
      "pause" -> result.success(DictationService.instance?.pause())
      "resume" -> {
        DictationService.instance?.resume()
        result.success(null)
      }
      "stop" -> result.success(DictationService.instance?.stop())
      "isRunning" -> result.success(DictationService.instance != null)
      else -> result.notImplemented()
    }
  }

  private fun start(call: MethodCall, result: MethodChannel.Result) {
    if (!granted(Manifest.permission.RECORD_AUDIO)) {
      result.error("microphone_denied", "RECORD_AUDIO is not granted", null)
      return
    }
    val sessionId = call.argument<String>("sessionId") ?: "s${System.currentTimeMillis()}"
    val dir = chunkDir().also { it.mkdirs() }
    val options = DictationService.Options(
      sessionId = sessionId,
      sampleRate = call.argument<Int>("sampleRate") ?: 16_000,
      bitRate = call.argument<Int>("bitRate") ?: 64_000,
      dir = dir.absolutePath,
      silenceDb = call.argument<Double>("silenceDb") ?: -30.0,
      minVoicedMs = (call.argument<Number>("minVoicedMs") ?: 300).toLong(),
      wakeLockMs = (call.argument<Number>("wakeLockMs") ?: (65 * 60_000)).toLong(),
      audioSource = when (call.argument<String>("audioSource")) {
        "voice_recognition" -> MediaRecorder.AudioSource.VOICE_RECOGNITION
        "voice_communication" -> MediaRecorder.AudioSource.VOICE_COMMUNICATION
        else -> MediaRecorder.AudioSource.MIC
      },
      title = call.argument<String>("title") ?: "Ghostkey is listening",
      text = call.argument<String>("text") ?: "Dictation keeps recording while the screen is off.",
    )
    try {
      DictationService.start(context, options)
      result.success(sessionId)
    } catch (e: Exception) {
      // Android 12+ throws here when a foreground service may not be started
      // from where the app currently is (it is in the background).
      result.error("service_start_refused", e.message ?: e.toString(), null)
    }
  }

  private fun chunkDir() = File(context.cacheDir, CHUNK_DIR)

  // ── Permissions ───────────────────────────────────────────────────────────

  private fun granted(permission: String): Boolean =
    context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

  private fun notificationsGranted(): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || granted(Manifest.permission.POST_NOTIFICATIONS)

  private fun request(permission: String, code: Int, result: MethodChannel.Result) {
    if (granted(permission)) {
      result.success(true)
      return
    }
    val act = activity
    if (act == null) {
      result.success(false)
      return
    }
    // One request of each kind in flight at a time; a second asker gets the
    // same answer as the first.
    if (permissionResults.containsKey(code)) {
      result.success(false)
      return
    }
    permissionResults[code] = result
    act.requestPermissions(arrayOf(permission), code)
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<String>,
    grantResults: IntArray,
  ): Boolean {
    val result = permissionResults.remove(requestCode) ?: return false
    result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
    return true
  }

  // ── Events ────────────────────────────────────────────────────────────────

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    if (sink == null) return
    RecorderBus.listener = object : DictationService.Listener {
      override fun onStarted(sessionId: String, sampleRate: Int, backgroundCapable: Boolean) = sink.success(
        mapOf(
          "event" to "started",
          "sessionId" to sessionId,
          "sampleRate" to sampleRate,
          "backgroundCapable" to backgroundCapable,
        ),
      )

      override fun onLevel(db: Double, elapsedMs: Long) = sink.success(
        mapOf("event" to "level", "db" to db, "elapsedMs" to elapsedMs),
      )

      override fun onChunk(
        index: Int,
        path: String,
        startFrame: Long,
        endFrame: Long,
        durationMs: Long,
        startMs: Long,
        endMs: Long,
        heardSpeech: Boolean,
        voicedMs: Long,
      ) = sink.success(
        mapOf(
          "event" to "chunk",
          "index" to index,
          "path" to path,
          "startFrame" to startFrame,
          "endFrame" to endFrame,
          "durationMs" to durationMs,
          "startMs" to startMs,
          "endMs" to endMs,
          "heardSpeech" to heardSpeech,
          "voicedMs" to voicedMs,
        ),
      )

      override fun onStopped(reason: String, samplesIn: Long, framesOut: Long) = sink.success(
        mapOf("event" to "stopped", "reason" to reason, "samplesIn" to samplesIn, "framesOut" to framesOut),
      )

      override fun onError(code: String, message: String) = sink.success(
        mapOf("event" to "error", "code" to code, "message" to message),
      )
    }
  }

  override fun onCancel(arguments: Any?) {
    RecorderBus.listener = null
  }

  companion object {
    const val METHODS = "ghostkey/recorder"
    const val EVENTS = "ghostkey/recorder/events"
    /** Under the app's cache dir; the Dart orphan sweep reads the same name. */
    const val CHUNK_DIR = "dictation"
    private const val REQ_MIC = 7301
    private const val REQ_NOTIFICATIONS = 7302
  }
}
