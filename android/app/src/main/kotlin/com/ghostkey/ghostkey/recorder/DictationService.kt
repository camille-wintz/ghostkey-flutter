package com.ghostkey.ghostkey.recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

/**
 * The microphone-type foreground service that owns a dictation session:
 * ONE AudioRecord, read continuously on a dedicated thread for the whole
 * session, encoded by ONE [AacChunkWriter]. Nothing here stops and re-arms
 * at a chunk boundary — a "chunk" is a cut of the encoded stream into files,
 * asked for by the Dart policy through [cut].
 *
 * The service is started from the record button (foregrounded, as Android 14
 * requires for a microphone service), holds a partial wake lock, shows the
 * mandatory notification with a Stop action, and reports to Dart through
 * [RecorderBus]. It is a singleton by construction ([instance]): the plugin
 * talks to it directly rather than through a binder, because both live in the
 * one process and there is at most one session.
 */
class DictationService : Service() {

  /** Everything Dart needs to know, on the main thread. */
  interface Listener {
    fun onStarted(sessionId: String, sampleRate: Int, backgroundCapable: Boolean)
    fun onLevel(db: Double, elapsedMs: Long)
    fun onChunk(
      index: Int,
      path: String,
      startFrame: Long,
      endFrame: Long,
      durationMs: Long,
      startMs: Long,
      endMs: Long,
      heardSpeech: Boolean,
      voicedMs: Long,
    )
    fun onStopped(reason: String, samplesIn: Long, framesOut: Long)
    fun onError(code: String, message: String)
  }

  class Options(
    val sessionId: String,
    val sampleRate: Int,
    val bitRate: Int,
    val dir: String,
    val silenceDb: Double,
    val minVoicedMs: Long,
    val wakeLockMs: Long,
    val audioSource: Int,
    val title: String,
    val text: String,
  ) {
    fun toIntent(intent: Intent): Intent = intent
      .putExtra("sessionId", sessionId)
      .putExtra("sampleRate", sampleRate)
      .putExtra("bitRate", bitRate)
      .putExtra("dir", dir)
      .putExtra("silenceDb", silenceDb)
      .putExtra("minVoicedMs", minVoicedMs)
      .putExtra("wakeLockMs", wakeLockMs)
      .putExtra("audioSource", audioSource)
      .putExtra("title", title)
      .putExtra("text", text)

    companion object {
      fun from(intent: Intent) = Options(
        sessionId = intent.getStringExtra("sessionId") ?: "session",
        sampleRate = intent.getIntExtra("sampleRate", 16_000),
        bitRate = intent.getIntExtra("bitRate", 64_000),
        dir = intent.getStringExtra("dir") ?: "",
        silenceDb = intent.getDoubleExtra("silenceDb", -30.0),
        minVoicedMs = intent.getLongExtra("minVoicedMs", 300L),
        wakeLockMs = intent.getLongExtra("wakeLockMs", 65 * 60_000L),
        audioSource = intent.getIntExtra("audioSource", MediaRecorder.AudioSource.MIC),
        title = intent.getStringExtra("title") ?: "Ghostkey is listening",
        text = intent.getStringExtra("text") ?: "Dictation keeps recording while the screen is off.",
      )
    }
  }

  private val main = Handler(Looper.getMainLooper())
  private var options: Options? = null
  private var record: AudioRecord? = null
  private var writer: AacChunkWriter? = null
  private var thread: Thread? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private val running = AtomicBoolean(false)
  @Volatile private var paused = false
  @Volatile private var cutRequested = false
  @Volatile private var stopReason: String? = null
  private var backgroundCapable = false

  // Per-chunk speech accounting, on the capture thread. Dart owns the silence
  // policy and computes its own count from the level events; this mirror only
  // exists so a chunk the NATIVE side finishes (the notification's Stop, a task
  // removal) is still judged when Dart may not have seen its last levels.
  private var chunkVoicedMs = 0L

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    instance = this
  }

  override fun onDestroy() {
    endSession(stopReason ?: "destroyed")
    if (instance === this) instance = null
    super.onDestroy()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_START -> startSession(Options.from(intent))
      ACTION_STOP -> endSession("notification")
      else -> if (!running.get()) stopSelf()
    }
    return START_NOT_STICKY
  }

  // The writer swiped the app out of recents. A mic with no screen behind it
  // is not a session anyone can finish; end it and leave the file for the sweep.
  override fun onTaskRemoved(rootIntent: Intent?) {
    endSession("task_removed")
    super.onTaskRemoved(rootIntent)
  }

  // ── Commands (main thread) ────────────────────────────────────────────────

  /** Ask for the running chunk to end. Returns the path of the file being finished. */
  fun cut(): String? {
    val w = writer ?: return null
    if (!running.get()) return null
    val path = w.currentPath
    cutRequested = true
    return path
  }

  /** Cut, then stop feeding the encoder. The mic stays open so resume has no seam. */
  fun pause(): String? {
    val path = cut()
    paused = true
    return path
  }

  fun resume() {
    paused = false
  }

  /** End the session from the client. Returns the path of the last chunk file, or null. */
  fun stop(): String? {
    val path = writer?.currentPath
    endSession("client")
    return path
  }

  // ── Session ───────────────────────────────────────────────────────────────

  private fun startSession(opts: Options) {
    if (running.get()) endSession("restarted")
    options = opts
    backgroundCapable = enterForeground(opts)
    acquireWakeLock(opts.wakeLockMs)

    val record = openRecord(opts)
    if (record == null) {
      fail("audio_record_unavailable", "AudioRecord could not be initialised at ${opts.sampleRate} Hz")
      return
    }
    val writer = try {
      AacChunkWriter(record.sampleRate, opts.bitRate, File(opts.dir), opts.sessionId, ::reportChunk)
    } catch (e: Exception) {
      record.release()
      fail("encoder_unavailable", e.message ?: e.toString())
      return
    }
    this.record = record
    this.writer = writer
    paused = false
    cutRequested = false
    stopReason = null
    chunkVoicedMs = 0
    running.set(true)
    try {
      record.startRecording()
    } catch (e: IllegalStateException) {
      running.set(false)
      writer.abandon()
      record.release()
      fail("audio_record_start_failed", e.message ?: e.toString())
      return
    }
    thread = Thread({ captureLoop(record, writer, opts) }, "ghostkey-dictation").also { it.start() }
    val sampleRate = record.sampleRate
    main.post { RecorderBus.listener?.onStarted(opts.sessionId, sampleRate, backgroundCapable) }
  }

  /**
   * Stop the capture thread, flush the encoder into the last file, report it
   * and the stop, drop the foreground state. Idempotent.
   */
  @Synchronized
  private fun endSession(reason: String) {
    if (!running.getAndSet(false)) return
    stopReason = reason
    thread?.let { t ->
      runCatching { t.join(4_000) }
    }
    thread = null
    val w = writer
    val r = record
    writer = null
    record = null
    runCatching { r?.stop() }
    runCatching { r?.release() }
    var samplesIn = 0L
    var framesOut = 0L
    if (w != null) {
      try {
        w.finish()
      } catch (e: Exception) {
        Log.w(TAG, "encoder flush failed", e)
        w.abandon()
      }
      samplesIn = w.samplesIn
      framesOut = w.framesOut
    }
    releaseWakeLock()
    main.post { RecorderBus.listener?.onStopped(reason, samplesIn, framesOut) }
    runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
    stopSelf()
  }

  private fun fail(code: String, message: String) {
    Log.e(TAG, "$code: $message")
    main.post { RecorderBus.listener?.onError(code, message) }
    releaseWakeLock()
    runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
    stopSelf()
  }

  // ── Capture thread ────────────────────────────────────────────────────────

  private fun captureLoop(record: AudioRecord, writer: AacChunkWriter, opts: Options) {
    Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
    val sampleRate = record.sampleRate
    val readSamples = sampleRate * READ_MS / 1000
    val meterSamples = sampleRate * LEVEL_MS / 1000
    val frame = ShortArray(readSamples)
    var sumSquares = 0.0
    var metered = 0
    try {
      while (running.get()) {
        val n = record.read(frame, 0, frame.size)
        if (n < 0) {
          throw IllegalStateException("AudioRecord.read returned $n")
        }
        if (n == 0) continue

        if (cutRequested) {
          cutRequested = false
          chunkVoicedMs = 0
          writer.cutAt()
        }

        if (paused) {
          // The mic keeps running so resume costs nothing, but nothing is
          // encoded — except the few AUs a pending cut still needs to emerge,
          // fed as silence so the file the writer asked for actually closes.
          if (writer.cutPending) writer.writeSilence(n)
          continue
        }

        writer.write(frame, n)

        for (i in 0 until n) {
          val s = frame[i].toDouble()
          sumSquares += s * s
        }
        metered += n
        if (metered >= meterSamples) {
          val rms = sqrt(sumSquares / metered)
          val db = if (rms <= 0.0) SILENCE_DB else max(SILENCE_DB, 20.0 * log10(rms / 32768.0))
          val windowMs = metered * 1000L / sampleRate
          if (db >= opts.silenceDb) chunkVoicedMs += windowMs
          val elapsedMs = writer.samplesIn * 1000L / sampleRate
          sumSquares = 0.0
          metered = 0
          main.post { RecorderBus.listener?.onLevel(db, elapsedMs) }
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "capture failed", e)
      if (running.get()) {
        main.post {
          RecorderBus.listener?.onError("capture_failed", e.message ?: e.toString())
          endSession("error")
        }
      }
    }
  }

  // Called on the capture thread by the writer whenever a file closes.
  private fun reportChunk(chunk: AacChunkWriter.Chunk) {
    val sampleRate = writer?.sampleRate ?: options?.sampleRate ?: 16_000
    val opts = options
    val voicedMs = chunkVoicedMs
    val heardSpeech = opts != null && voicedMs >= opts.minVoicedMs
    val startMs = chunk.startFrame * AacChunkWriter.AAC_FRAME * 1000L / sampleRate
    val endMs = chunk.endFrame * AacChunkWriter.AAC_FRAME * 1000L / sampleRate
    val path = chunk.file.absolutePath
    main.post {
      RecorderBus.listener?.onChunk(
        chunk.index, path, chunk.startFrame, chunk.endFrame,
        endMs - startMs, startMs, endMs, heardSpeech, voicedMs,
      )
    }
  }

  // ── Hardware ──────────────────────────────────────────────────────────────

  private fun openRecord(opts: Options): AudioRecord? {
    for (rate in listOf(opts.sampleRate, 44_100, 48_000).distinct()) {
      val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
      if (min <= 0) continue
      // A deep buffer (two seconds) is part of the "nothing lost" promise: a
      // late capture thread — a GC pause, a muxer rotation, the phone busy
      // under lock — must never overrun the hardware buffer.
      val size = max(min * 4, rate * 2 * BUFFER_SECONDS)
      val r = try {
        AudioRecord(opts.audioSource, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size)
      } catch (e: Exception) {
        Log.w(TAG, "AudioRecord at $rate Hz failed", e)
        null
      } ?: continue
      if (r.state == AudioRecord.STATE_INITIALIZED) return r
      r.release()
    }
    return null
  }

  /** Post the notification and take the microphone foreground type. False when the OS refused. */
  private fun enterForeground(opts: Options): Boolean {
    val manager = getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(CHANNEL_ID, "Dictation", NotificationManager.IMPORTANCE_LOW)
      channel.setShowBadge(false)
      manager.createNotificationChannel(channel)
    }
    val stopIntent = PendingIntent.getService(
      this, 1,
      Intent(this, DictationService::class.java).setAction(ACTION_STOP),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val launch = packageManager.getLaunchIntentForPackage(packageName)
    val openIntent = launch?.let {
      PendingIntent.getActivity(this, 2, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, CHANNEL_ID)
    } else {
      @Suppress("DEPRECATION") Notification.Builder(this)
    }
    val notification = builder
      .setContentTitle(opts.title)
      .setContentText(opts.text)
      // The app has no monochrome glyph yet (background-recording-plan §3.G);
      // the stock mic reads correctly until it does.
      .setSmallIcon(android.R.drawable.ic_btn_speak_now)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setVisibility(Notification.VISIBILITY_PUBLIC)
      .apply { if (openIntent != null) setContentIntent(openIntent) }
      .addAction(
        Notification.Action.Builder(
          Icon.createWithResource(this, android.R.drawable.ic_media_pause), "Stop", stopIntent,
        ).build(),
      )
      .build()
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
      } else {
        startForeground(NOTIFICATION_ID, notification)
      }
      true
    } catch (e: Exception) {
      // Android 12+ refuses a foreground start from the background, 14+ a
      // microphone type the app may not use right now. The session still
      // records while the activity is visible; Dart is told it is
      // foreground-only.
      Log.w(TAG, "startForeground refused", e)
      false
    }
  }

  private fun acquireWakeLock(timeoutMs: Long) {
    try {
      val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
      val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ghostkey:dictation")
      lock.setReferenceCounted(false)
      lock.acquire(timeoutMs)
      wakeLock = lock
    } catch (e: Exception) {
      // WAKE_LOCK not in the manifest: the mic-type service alone keeps most
      // devices awake; a vendor that does not is a device-matrix finding.
      Log.w(TAG, "wake lock unavailable", e)
      wakeLock = null
    }
  }

  private fun releaseWakeLock() {
    wakeLock?.let { if (it.isHeld) runCatching { it.release() } }
    wakeLock = null
  }

  companion object {
    private const val TAG = "GhostkeyRecorder"
    const val ACTION_START = "com.ghostkey.ghostkey.recorder.START"
    const val ACTION_STOP = "com.ghostkey.ghostkey.recorder.STOP"
    private const val CHANNEL_ID = "ghostkey_dictation"
    private const val NOTIFICATION_ID = 731
    /** One AudioRecord read, and the cadence the capture thread wakes at. */
    private const val READ_MS = 20
    /** The metering window; one level event per window. */
    private const val LEVEL_MS = 100
    private const val BUFFER_SECONDS = 2
    private const val SILENCE_DB = -160.0

    /** The live service, while one exists. Set in onCreate, cleared in onDestroy. */
    @Volatile var instance: DictationService? = null
      private set

    fun start(context: Context, options: Options) {
      val intent = options.toIntent(Intent(context, DictationService::class.java).setAction(ACTION_START))
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent)
      } else {
        context.startService(intent)
      }
    }
  }
}

/** The one listener the service reports to — the plugin's event sink, while Dart is listening. */
object RecorderBus {
  @Volatile var listener: DictationService.Listener? = null
}
