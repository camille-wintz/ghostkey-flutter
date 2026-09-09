import 'json.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String email;

  /// Confirmed address? Reported, never enforced — the server signs unverified
  /// accounts in like any other; Account just badges them.
  final bool emailVerified;

  static AuthUser fromJson(Json json) => AuthUser(
        id: asString(json['id']),
        email: asString(json['email']),
        emailVerified: asBool(json['email_verified']),
      );
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String expiresAt;
  final AuthUser user;

  static AuthSession fromJson(Json json) => AuthSession(
        accessToken: asString(json['access_token']),
        refreshToken: asString(json['refresh_token']),
        expiresAt: asString(json['expires_at']),
        user: AuthUser.fromJson(asJson(json['user'])),
      );
}
