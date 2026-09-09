import 'dart:async';

import 'package:flutter/services.dart';

import 'policy.dart';

// The Dart end of the native recorder (android/…/recorder/README.md is the
// contract). Nothing here decides anything: it turns method calls and event
// maps into typed values for session.dart.

sealed class RecorderEvent {
  const RecorderEvent();

  static RecorderEvent? fromMap(Map<Object?, Object?> map) => switch (map['event']) {
        'started' => RecorderStarted(
            sessionId: map['sessionId'] as String? ?? '',
            sampleRate: (map['sampleRate'] as num?)?.toInt() ?? DictationPolicy.sampleRate,
            backgroundCapable: map['backgroundCapable'] as bool? ?? false,
          ),
        'level' => RecorderLevel(
            db: (map['db'] as num?)?.toDouble() ?? -160,
            elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
          ),
        'chunk' => RecorderChunk(
            index: (map['index'] as num?)?.toInt() ?? 0,
            path: map['path'] as String? ?? '',
            startFrame: (map['startFrame'] as num?)?.toInt() ?? 0,
            endFrame: (map['endFrame'] as num?)?.toInt() ?? 0,
            durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
            heardSpeech: map['heardSpeech'] as bool? ?? false,
            voicedMs: (map['voicedMs'] as num?)?.toInt() ?? 0,
          ),
        'stopped' => RecorderStopped(
            reason: NativeStopReason.parse(map['reason'] as String?),
            samplesIn: (map['samplesIn'] as num?)?.toInt() ?? 0,
            framesOut: (map['framesOut'] as num?)?.toInt() ?? 0,
          ),
        'error' => RecorderError(
            code: map['code'] as String? ?? 'unknown',
            message: map['message'] as String? ?? '',
          ),
        _ => null,
      };
}

class RecorderStarted extends RecorderEvent {
  const RecorderStarted({required this.sessionId, required this.sampleRate, required this.backgroundCapable});
  final String sessionId;
  final int sampleRate;

  /// False when the OS refused the microphone foreground type: the session
  /// records only while the activity is visible.
  final bool backgroundCapable;
}

class RecorderLevel extends RecorderEvent {
  const RecorderLevel({required this.db, required this.elapsedMs});

  /// RMS over the last 100 ms, in dBFS.
  final double db;

  /// Audio time fed to the encoder — excludes pauses.
  final int elapsedMs;
}

class RecorderChunk extends RecorderEvent {
  const RecorderChunk({
    required this.index,
    required this.path,
    required this.startFrame,
    required this.endFrame,
    required this.durationMs,
    required this.heardSpeech,
    required this.voicedMs,
  });
  final int index;
  final String path;

  /// AAC access-unit indices in the session's one encoded stream. Consecutive
  /// chunks meet exactly; SeamLedger checks that they do.
  final int startFrame;
  final int endFrame;
  final int durationMs;

  /// The native side's own judgement, for a chunk it finished without a cut
  /// from here (the notification's Stop, a task removal).
  final bool heardSpeech;
  final int voicedMs;
}

/// Why the native session ended. `client` is a stop this side asked for;
/// everything else is the native side ending it on its own.
enum NativeStopReason {
  client,
  notification,
  taskRemoved,
  error,
  restarted,
  destroyed;

  static NativeStopReason parse(String? s) => switch (s) {
        'client' => client,
        'notification' => notification,
        'task_removed' => taskRemoved,
        'error' => error,
        'restarted' => restarted,
        _ => destroyed,
      };
}

class RecorderStopped extends RecorderEvent {
  const RecorderStopped({required this.reason, required this.samplesIn, required this.framesOut});
  final NativeStopReason reason;
  final int samplesIn;
  final int framesOut;
}

class RecorderError extends RecorderEvent {
  const RecorderError({required this.code, required this.message});
  final String code;
  final String message;
}

class RecorderPermissions {
  const RecorderPermissions({required this.sdk, required this.microphone, required this.notifications});
  final int sdk;
  final bool microphone;
  final bool notifications;
}

enum AudioSource { mic, voiceRecognition, voiceCommunication }

class RecorderOptions {
  const RecorderOptions({
    required this.sessionId,
    this.sampleRate = DictationPolicy.sampleRate,
    this.bitRate = DictationPolicy.bitRate,
    this.silenceDb = DictationPolicy.silenceDbThreshold,
    this.minVoicedMs = DictationPolicy.minVoicedMs,
    this.wakeLockMs = DictationPolicy.maxSessionMs + 5 * 60000,
    this.audioSource = AudioSource.mic,
    this.title = 'Ghostkey is listening',
    this.text = 'Dictation keeps recording while the screen is off.',
  });
  final String sessionId;
  final int sampleRate;
  final int bitRate;
  final double silenceDb;
  final int minVoicedMs;
  final int wakeLockMs;
  final AudioSource audioSource;
  final String title;
  final String text;

  Map<String, Object?> toMap() => {
        'sessionId': sessionId,
        'sampleRate': sampleRate,
        'bitRate': bitRate,
        'silenceDb': silenceDb,
        'minVoicedMs': minVoicedMs,
        'wakeLockMs': wakeLockMs,
        'audioSource': switch (audioSource) {
          AudioSource.mic => 'mic',
          AudioSource.voiceRecognition => 'voice_recognition',
          AudioSource.voiceCommunication => 'voice_communication',
        },
        'title': title,
        'text': text,
      };
}

/// Thrown when the native side refuses to start (no microphone permission,
/// or a foreground service may not be started from where the app is).
class RecorderStartException implements Exception {
  const RecorderStartException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'RecorderStartException($code): $message';
}

class NativeRecorder {
  static const _methods = MethodChannel('ghostkey/recorder');
  static const _events = EventChannel('ghostkey/recorder/events');

  Stream<RecorderEvent>? _stream;

  /// The native event stream. Subscribe BEFORE [start]: the native side only
  /// reports while something is listening.
  Stream<RecorderEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((e) => e is Map<Object?, Object?> ? RecorderEvent.fromMap(e) : null)
      .where((e) => e != null)
      .cast<RecorderEvent>();

  Future<RecorderPermissions> permissions() async {
    final map = await _methods.invokeMapMethod<String, Object?>('permissions') ?? const {};
    return RecorderPermissions(
      sdk: (map['sdk'] as num?)?.toInt() ?? 0,
      microphone: map['microphone'] as bool? ?? false,
      notifications: map['notifications'] as bool? ?? false,
    );
  }

  Future<bool> requestMicrophone() async => await _methods.invokeMethod<bool>('requestMicrophone') ?? false;

  Future<bool> requestNotifications() async =>
      await _methods.invokeMethod<bool>('requestNotifications') ?? false;

  Future<String> chunkDirectory() async => await _methods.invokeMethod<String>('chunkDirectory') ?? '';

  /// Start a session. Resolves with the session id once the service has been
  /// asked to start; the session is live when the `started` event arrives.
  Future<String> start(RecorderOptions options) async {
    try {
      return await _methods.invokeMethod<String>('start', options.toMap()) ?? options.sessionId;
    } on PlatformException catch (e) {
      throw RecorderStartException(e.code, e.message ?? e.code);
    }
  }

  /// Ask for the running chunk to end. Resolves with the path of the file
  /// being finished; its `chunk` event follows.
  Future<String?> cut() => _methods.invokeMethod<String>('cut');

  Future<String?> pause() => _methods.invokeMethod<String>('pause');

  Future<void> resume() => _methods.invokeMethod<void>('resume');

  /// End the session. Resolves with the path of the last file; its `chunk`
  /// event (if it holds anything) and the `stopped` event follow.
  Future<String?> stop() => _methods.invokeMethod<String>('stop');

  Future<bool> isRunning() async => await _methods.invokeMethod<bool>('isRunning') ?? false;
}
