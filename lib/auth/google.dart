import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../server/errors.dart';

// Everything this app knows about Google. The server verifies the token
// (`POST /api/auth/google`); nothing here trusts it.

/// The WEB client of Google Cloud project `ghostkey-508619`, named as the
/// server client so the ID token is addressed to the one audience the server
/// accepts. The Android clients (one per package name + signing certificate:
/// `app.ghostkey` under the upload key and under Play's, `app.ghostkey.dev`
/// under the debug key) are never named in code — Google matches them to the
/// installed APK, and a build whose pair is not registered fails here.
const _serverClientId = '881615790018-q3h39j68issb5t7l2n4j7n8kkupbia0o.apps.googleusercontent.com';

Future<void>? _ready;

/// Ask the phone's Google account picker for an ID token. Null when the
/// author backed out of it.
Future<String?> askGoogleForIdToken() async {
  try {
    await (_ready ??= GoogleSignIn.instance.initialize(serverClientId: _serverClientId));
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    debugPrint('[auth] Google sign-in failed: ${e.code} ${e.description}');
    throw ServerError('google_failed', 0, e.toString());
  }
}
