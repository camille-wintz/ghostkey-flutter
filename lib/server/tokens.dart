// The client's window onto the session, without importing it.
//
// `client.dart` needs three things from whoever owns the session: the current
// access token, a way to refresh it, and a way to say it is gone. The offline
// mirror needs a fourth — whose copies it is keeping. Registered
// here as callbacks so the client stays ignorant of the session's shape — the
// same split the RN app made between `tokens.ts` and `authStore.ts`.

typedef AccessTokenGetter = String? Function();
typedef TokenRefresher = Future<String?> Function();
typedef AuthLostHandler = void Function();
typedef UserIdGetter = String? Function();

class TokenHandlers {
  const TokenHandlers({
    required this.getAccessToken,
    required this.onRefresh,
    required this.onAuthLost,
    required this.getUserId,
  });

  final AccessTokenGetter getAccessToken;
  final TokenRefresher onRefresh;
  final AuthLostHandler onAuthLost;
  final UserIdGetter getUserId;
}

TokenHandlers? _handlers;

void setTokenHandlers(TokenHandlers next) => _handlers = next;

void clearTokenHandlers() => _handlers = null;

String? getAccessToken() => _handlers?.getAccessToken();

String? getUserId() => _handlers?.getUserId();

Future<String?> refreshAccessToken() async => _handlers?.onRefresh();

void notifyAuthLost() => _handlers?.onAuthLost();
