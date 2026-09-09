import 'dart:convert';

import 'package:http/http.dart' as http;

import '../client.dart';
import '../config.dart';
import '../dto/auth.dart';
import '../dto/json.dart';
import '../errors.dart';

/// An unauthenticated POST to `/api/auth/*`, with the server's error code
/// lifted out of the body. Returns the response rather than a parsed value:
/// `forgot-password` answers with a deliberately empty `200`.
Future<http.Response> _postAuth(String path, Json body) async {
  http.Response res;
  try {
    res = await http.post(
      Uri.parse('$serverBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  } catch (e) {
    throw ServerError('network_error', 0, e.toString());
  }

  if (res.statusCode < 200 || res.statusCode >= 300) {
    var code = 'unknown';
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['error'] is String) code = data['error'] as String;
    } catch (_) {
      // body wasn't JSON
    }
    // The edge limiter answers 429 with `Retry-After` and nothing useful in
    // the body.
    final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
    throw ServerError(
      code == 'unknown' && res.statusCode == 429 ? 'rate_limited' : code,
      res.statusCode,
      null,
      null,
      retryAfter != null && retryAfter > 0 ? retryAfter : null,
    );
  }
  return res;
}

Future<AuthSession> _postSession(String path, Json body) async {
  final res = await _postAuth(path, body);
  return AuthSession.fromJson(asJson(jsonDecode(res.body)));
}

Future<AuthSession> postSignup(String email, String password) =>
    _postSession('/api/auth/signup', {'email': email, 'password': password});

Future<AuthSession> postSignin(String email, String password) =>
    _postSession('/api/auth/signin', {'email': email, 'password': password});

Future<AuthSession> postRefresh(String refreshToken) =>
    _postSession('/api/auth/refresh', {'refresh_token': refreshToken});

/// What a resend attempt came to: whether mail went out, and how many seconds
/// before the server accepts another ask either way.
class ResendVerificationResult {
  const ResendVerificationResult({required this.sent, required this.retryAfter});
  final bool sent;
  final int retryAfter;
}

/// Ask for another verification email for the signed-in account. A cooldown
/// refusal is a return value, not a throw.
Future<ResendVerificationResult> postResendVerification() async {
  try {
    final res = await apiFetch('/api/auth/resend-verification', method: 'POST', body: const <String, dynamic>{});
    return ResendVerificationResult(sent: true, retryAfter: asInt(res.jsonObject()['retry_after']));
  } on ServerError catch (e) {
    if (e.code == 'rate_limited') return ResendVerificationResult(sent: false, retryAfter: e.retryAfter ?? 60);
    rethrow;
  }
}

/// Ask for a password-reset email. Nothing comes back by design: the route
/// answers an empty `200` for an address it has never seen too. The link in
/// the mail opens the web app; this is the whole of reset on the phone.
Future<void> postForgotPassword(String email) async {
  await _postAuth('/api/auth/forgot-password', {'email': email});
}

Future<void> postSignout(String refreshToken) async {
  try {
    await http.post(
      Uri.parse('$serverBaseUrl/api/auth/signout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  } catch (_) {
    // server signout is best-effort; local state is cleared regardless
  }
}
