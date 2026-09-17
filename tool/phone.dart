// Builds a debug APK, installs it over the one on the phone, and opens it.
//
//   dart tool/phone.dart            staging
//   dart tool/phone.dart prod
//   dart tool/phone.dart lan        the LAN server from .vscode/launch.json
//   dart tool/phone.dart http://192.168.1.23:3000
//
// Plain dart:io so it runs the same on the Mac and on Windows. The phone needs
// USB debugging on and has to show up in `adb devices`.
import 'dart:io';

const servers = {
  'staging': 'https://ghostkey-server-staging.fly.dev',
  'prod': 'https://api.ghost-key.app',
  'lan': 'http://192.168.1.10:3000',
};

const apk = 'build/app/outputs/flutter-apk/app-debug.apk';
const activity = 'app.ghostkey.dev/com.ghostkey.ghostkey.MainActivity';

Future<void> main(List<String> args) async {
  final target = args.isEmpty ? 'staging' : args.first;
  final url = target.startsWith('http') ? target : servers[target];
  if (url == null) {
    stderr.writeln('Unknown target "$target". Use ${servers.keys.join(' | ')} or a URL.');
    exit(64);
  }

  // Run from the repo root whatever the caller's cwd.
  Directory.current = File.fromUri(Platform.script).parent.parent;

  stdout.writeln('→ $url');
  await step('flutter', ['build', 'apk', '--debug', '--dart-define=GHOSTKEY_SERVER_URL=$url']);
  await step('adb', ['install', '-r', apk]);
  await step('adb', ['shell', 'am', 'start', '-n', activity]);
}

Future<void> step(String exe, List<String> args) async {
  stdout.writeln('\$ $exe ${args.join(' ')}');
  // runInShell so Windows finds flutter.bat.
  final p = await Process.start(exe, args, mode: ProcessStartMode.inheritStdio, runInShell: true);
  final code = await p.exitCode;
  if (code != 0) exit(code);
}
