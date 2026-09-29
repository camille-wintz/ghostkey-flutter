import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import 'config.dart';
import 'dto/realtime.dart';
import 'tokens.dart';

// The realtime client for the server's /ws fanout — one socket for the app,
// shared by every reader. The same protocol as the desktop's
// ghost-key/core/cloud/ws.ts: auth through the `ghostkey-v1, bearer.<token>`
// subprotocol pair, a subscribe frame per project, a flat 10 s redial, and a
// resync signal after every reconnect — events during a gap are lost by
// design, so a reader re-reads what it shows. The server sends `{type:
// "ping"}` every 30 s so a silent wire can be told from a quiet one: 75 s of
// nothing is a dead socket (half-open, usually a phone that slept), dropped
// and redialled.
//
// Subscriptions only grow, as on the desk: the fanout is already scoped to the
// account, and a book opened once this session is cheap to keep hearing.

/// What a reader needs from the socket. An interface so a test can feed
/// events without one.
abstract interface class RealtimeFeed {
  /// Every change to [projectId], subscribing on first ask.
  Stream<ProjectChangeEvent> project(String projectId);

  /// Fires after every reconnect (never on the first open): re-read now.
  Stream<void> get resyncs;

  /// The app came back to the foreground.
  void wake();
}

class Realtime implements RealtimeFeed {
  static const _redial = Duration(seconds: 10);
  static const _liveness = Duration(seconds: 75);
  static const _livenessCheck = Duration(seconds: 15);
  static const _connectTimeout = Duration(seconds: 15);

  /// Longer than one missed ping: after a pause this long the socket is
  /// suspect, and dropping a live one costs one reconnect and one re-read.
  static const _pauseSuspicion = Duration(seconds: 35);

  final Set<String> _projects = {};
  final StreamController<ProjectChangeEvent> _changes = StreamController.broadcast();
  final StreamController<void> _resyncs = StreamController.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _frames;
  bool _connecting = false;
  bool _disposed = false;

  /// Non-zero after a drop: the next open is a reconnect and fires a resync.
  int _attempts = 0;
  Timer? _redialTimer;
  Timer? _watchdog;
  DateTime _lastFrameAt = DateTime.now();

  /// The token the last handshake used, and whether the server refused it —
  /// then the next dial refreshes first.
  String? _lastToken;
  bool _lastTokenRejected = false;

  @override
  Stream<ProjectChangeEvent> project(String projectId) {
    if (_projects.add(projectId)) _sendSubscribe(projectId);
    _ensureConnected();
    return _changes.stream.where((e) => e.projectId == projectId);
  }

  @override
  Stream<void> get resyncs => _resyncs.stream;

  /// Android lets a socket die while the app is away without telling it; the
  /// watchdog would find out a minute later. Back in front, a socket that has
  /// been silent too long is dropped and one is dialled now, not in 10 s.
  @override
  void wake() {
    if (_disposed) return;
    final socket = _socket;
    if (socket != null && DateTime.now().difference(_lastFrameAt) > _pauseSuspicion) {
      _drop(socket, 'silent across a pause');
    }
    if (_socket == null && !_connecting) {
      _redialTimer?.cancel();
      _redialTimer = null;
      _ensureConnected();
    }
  }

  void dispose() {
    _disposed = true;
    _redialTimer?.cancel();
    _watchdog?.cancel();
    unawaited(_frames?.cancel());
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close().catchError((_) {}));
    unawaited(_changes.close());
    unawaited(_resyncs.close());
  }

  void _sendSubscribe(String projectId) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(jsonEncode({'type': 'subscribe', 'project_id': projectId}));
    } catch (e) {
      _log('subscribe failed: $e');
    }
  }

  void _ensureConnected() {
    if (_disposed || _connecting || _socket != null || _projects.isEmpty) return;
    _connecting = true;
    unawaited(_connect());
  }

  Future<void> _connect() async {
    String? token;
    try {
      token = await _handshakeToken();
      if (token == null) {
        _connecting = false;
        // Signed out: nothing to dial until someone subscribes again. Signed
        // in with a refresh that failed (offline): keep knocking.
        if (getUserId() != null) _scheduleRedial();
        return;
      }
      final client = HttpClient()..connectionTimeout = _connectTimeout;
      final socket = await WebSocket.connect(
        _url(),
        protocols: ['ghostkey-v1', 'bearer.$token'],
        customClient: client,
      );
      if (_disposed) {
        unawaited(socket.close().catchError((_) {}));
        return;
      }
      _open(socket);
    } catch (e) {
      _connecting = false;
      if (e is WebSocketException && e.httpStatusCode == 401) {
        _lastTokenRejected = true;
        _log('handshake refused — refreshing before the next dial');
      } else {
        _log('connect failed: $e');
      }
      _scheduleRedial();
    }
  }

  /// The access token for the next handshake: the session's, unless the last
  /// dial was refused with it or it is about to lapse — then a refreshed one
  /// (the same serialized refresh every 401 goes through).
  Future<String?> _handshakeToken() async {
    final current = getAccessToken();
    final stale = current == null || (_lastTokenRejected && current == _lastToken) || _expiresSoon(current);
    final token = stale ? await refreshAccessToken() : current;
    _lastToken = token;
    _lastTokenRejected = false;
    return token;
  }

  void _open(WebSocket socket) {
    _socket = socket;
    _connecting = false;
    _lastFrameAt = DateTime.now();
    _ensureWatchdog();
    final reconnected = _attempts > 0;
    _attempts = 0;
    _log('connected${reconnected ? ' (reconnect)' : ''}');
    _frames = socket.listen(
      (data) {
        if (_socket != socket) return;
        // Any frame proves the wire, the server's ping included.
        _lastFrameAt = DateTime.now();
        if (data is! String) return;
        final Object? decoded;
        try {
          decoded = jsonDecode(data);
        } catch (_) {
          return;
        }
        if (ProjectChangeEvent.fromJson(decoded) case final event?) _changes.add(event);
      },
      onError: (Object e) => _log('socket error: $e'),
      onDone: () {
        if (_socket != socket) return;
        _socket = null;
        _frames = null;
        _scheduleRedial();
      },
    );
    for (final projectId in _projects) {
      _sendSubscribe(projectId);
    }
    if (reconnected) _resyncs.add(null);
  }

  /// Detach first, so the dead socket's late close is ignored, then close it
  /// best-effort — a half-open peer never answers the close handshake.
  void _drop(WebSocket socket, String why) {
    if (_socket != socket) return;
    _socket = null;
    unawaited(_frames?.cancel());
    _frames = null;
    _log('dropping socket: $why');
    unawaited(socket.close().catchError((_) {}));
    _scheduleRedial();
  }

  void _ensureWatchdog() {
    _watchdog ??= Timer.periodic(_livenessCheck, (_) {
      final socket = _socket;
      if (socket == null) return;
      final silent = DateTime.now().difference(_lastFrameAt);
      if (silent >= _liveness) _drop(socket, 'silent for ${silent.inSeconds}s');
    });
  }

  void _scheduleRedial() {
    if (_disposed || _redialTimer != null || _projects.isEmpty) return;
    _attempts++;
    _redialTimer = Timer(_redial, () {
      _redialTimer = null;
      _ensureConnected();
    });
  }

  String _url() => '${serverBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws';

  void _log(String message) {
    if (kDebugMode) debugPrint('[ws] $message');
  }
}

/// A JWT whose `exp` is within half a minute. Unreadable reads as fresh: the
/// server's 401 is the authority, this only saves a refused dial.
bool _expiresSoon(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (payload is! Map || payload['exp'] is! num) return false;
    final exp = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as num).toInt() * 1000);
    return exp.isBefore(DateTime.now().add(const Duration(seconds: 30)));
  } catch (_) {
    return false;
  }
}

/// The app's one socket. Rebuilt when the account signs in or out, so a
/// signed-out phone holds no socket and the next account never hears the
/// last one's books.
final realtimeProvider = Provider<RealtimeFeed>((ref) {
  ref.watch(signedInProvider);
  final realtime = Realtime();
  ref.onDispose(realtime.dispose);
  return realtime;
});
