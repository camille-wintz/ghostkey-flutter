import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/auth/api.dart';
import '../server/dto/auth.dart';
import '../server/errors.dart';
import '../server/secure_storage.dart';
import '../server/tokens.dart';

enum AuthStatus { hydrating, signedOut, signedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? accessToken;
  final String? refreshToken;

  bool get signedIn => status == AuthStatus.signedIn;

  static const hydrating = AuthState(status: AuthStatus.hydrating);
  static const signedOut = AuthState(status: AuthStatus.signedOut);
}

/// The session: who is signed in and the tokens that prove it.
///
/// Refresh tokens rotate on every use; presenting an already-rotated token
/// revokes the entire session chain. The two in-flight futures serialize
/// concurrent callers (a double hydrate, parallel 401s) onto one round-trip.
class Session extends Notifier<AuthState> {
  Future<void>? _hydrating;
  Future<String?>? _inflightRefresh;

  @override
  AuthState build() {
    setTokenHandlers(TokenHandlers(
      getAccessToken: () => state.accessToken,
      onRefresh: _refresh,
      onAuthLost: () => clearSession(),
    ));
    return AuthState.hydrating;
  }

  Future<void> setSession(AuthSession next, {StoredCredentials? credentials}) async {
    await setRefreshToken(next.refreshToken);
    if (credentials != null) await setStoredCredentials(credentials);
    state = AuthState(
      status: AuthStatus.signedIn,
      user: next.user,
      accessToken: next.accessToken,
      refreshToken: next.refreshToken,
    );
  }

  Future<void> clearSession() async {
    await clearRefreshToken();
    await clearStoredCredentials();
    state = AuthState.signedOut;
  }

  Future<void> hydrate() => _hydrating ??= _hydrateOnce();

  Future<void> _hydrateOnce() async {
    try {
      final stored = await getRefreshToken();
      if (stored != null) {
        try {
          await setSession(await postRefresh(stored));
          return;
        } on ServerError catch (e) {
          if (e.code == 'invalid_refresh_token') await clearRefreshToken();
        }
      }
      if (await _restoreWithStoredCredentials()) return;
      state = AuthState.signedOut;
    } catch (_) {
      state = AuthState.signedOut;
    }
  }

  Future<bool> _restoreWithStoredCredentials() async {
    final credentials = await getStoredCredentials();
    if (credentials == null) return false;
    try {
      await setSession(await postSignin(credentials.email, credentials.password), credentials: credentials);
      return true;
    } on ServerError catch (e) {
      if (e.code == 'invalid_credentials') await clearStoredCredentials();
      rethrow;
    }
  }

  Future<String?> _refresh() => _inflightRefresh ??= _refreshOnce().whenComplete(() => _inflightRefresh = null);

  Future<String?> _refreshOnce() async {
    final current = state.refreshToken;
    if (current == null) return null;
    if (kDebugMode) debugPrint('[auth] Access token rejected — refreshing session');
    try {
      final next = await postRefresh(current);
      await setSession(next);
      if (kDebugMode) debugPrint('[auth] Session refreshed');
      return next.accessToken;
    } on ServerError catch (e) {
      if (e.code == 'invalid_refresh_token') {
        debugPrint('[auth] Refresh token rejected by the server — signing out');
        await clearSession();
      } else {
        debugPrint('[auth] Session refresh failed (session kept): $e');
      }
      return null;
    } catch (e) {
      debugPrint('[auth] Session refresh failed (session kept): $e');
      return null;
    }
  }
}

final sessionProvider = NotifierProvider<Session, AuthState>(Session.new);

/// True while a user is signed in — what every server query is gated on.
final signedInProvider = Provider<bool>((ref) => ref.watch(sessionProvider).signedIn);
