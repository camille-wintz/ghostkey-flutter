import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// The two secrets this app keeps on the phone: the refresh token, and the
// credentials that let a session be rebuilt when the token chain is broken.
// Nothing about project content is ever stored here.

const _refreshTokenKey = 'ghostkey_refresh_token';
const _credentialsKey = 'ghostkey_auth_credentials';

const _storage = FlutterSecureStorage();

class StoredCredentials {
  const StoredCredentials({required this.email, required this.password});
  final String email;
  final String password;
}

Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

Future<void> setRefreshToken(String token) =>
    _storage.write(key: _refreshTokenKey, value: token);

Future<void> clearRefreshToken() => _storage.delete(key: _refreshTokenKey);

Future<StoredCredentials?> getStoredCredentials() async {
  final stored = await _storage.read(key: _credentialsKey);
  if (stored == null) return null;
  try {
    final data = jsonDecode(stored);
    if (data is Map<String, dynamic>) {
      final email = data['email'];
      final password = data['password'];
      if (email is String && password is String) {
        return StoredCredentials(email: email, password: password);
      }
    }
  } catch (_) {
    // Invalid cache entries are treated as absent credentials.
  }
  await clearStoredCredentials();
  return null;
}

Future<void> setStoredCredentials(StoredCredentials credentials) =>
    _storage.write(
      key: _credentialsKey,
      value: jsonEncode({
        'email': credentials.email,
        'password': credentials.password,
      }),
    );

Future<void> clearStoredCredentials() => _storage.delete(key: _credentialsKey);
