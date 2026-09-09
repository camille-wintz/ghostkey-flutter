// Where the server is.
//
// Baked in at compile time with `--dart-define=GHOSTKEY_SERVER_URL=…` (see the
// launch configurations in `.vscode/launch.json` and the `Makefile`). A build
// with no define fails HERE, on the first read, with a message that says what
// to do — never on the phone with a network error that looks like the server
// being down.

const String _rawBaseUrl = String.fromEnvironment('GHOSTKEY_SERVER_URL');

String get serverBaseUrl {
  if (_rawBaseUrl.isEmpty) {
    throw StateError(
      'GHOSTKEY_SERVER_URL is not set. Run with '
      '--dart-define=GHOSTKEY_SERVER_URL=https://ghostkey-server-staging.fly.dev '
      '(or http://<LAN IP>:3000 for a local server).',
    );
  }
  return _rawBaseUrl.replaceAll(RegExp(r'/+$'), '');
}
