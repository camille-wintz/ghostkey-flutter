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

  Json toJson() => {'id': id, 'email': email, 'email_verified': emailVerified};
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
    this.created = false,
  });

  final String accessToken;
  final String refreshToken;
  final String expiresAt;
  final AuthUser user;

  /// This call made the account. Google's door both signs in and registers,
  /// and only the server knows which it just did.
  final bool created;

  static AuthSession fromJson(Json json) => AuthSession(
        accessToken: asString(json['access_token']),
        refreshToken: asString(json['refresh_token']),
        expiresAt: asString(json['expires_at']),
        user: AuthUser.fromJson(asJson(json['user'])),
        created: json['created'] == true,
      );
}
