// Bumps the version in pubspec.yaml and builds the Play Store bundle against
// prod.
//
//   dart tool/release.dart            0.1.0+1 → 0.1.0+2   (build number only)
//   dart tool/release.dart patch      0.1.0+1 → 0.1.1+2
//   dart tool/release.dart minor      0.1.0+1 → 0.2.0+2
//   dart tool/release.dart major      0.1.0+1 → 1.0.0+2
//   dart tool/release.dart 1.4.0      0.1.0+1 → 1.4.0+2
//
// The build number goes up on every run, whatever the name does: Play refuses
// a bundle whose versionCode is not higher than every one uploaded before, on
// any track. The gates run first, and pubspec.yaml is put back if they or the
// build fail, so a failed run never burns a number.
//
// Signing needs android/key.properties (see android/app/build.gradle.kts).
import 'dart:io';

import 'phone.dart' show servers;

const bundle = 'build/app/outputs/bundle/release/app-release.aab';
final versionLine = RegExp(r'^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$', multiLine: true);

Future<void> main(List<String> args) async {
  Directory.current = File.fromUri(Platform.script).parent.parent;

  final pubspec = File('pubspec.yaml');
  final original = pubspec.readAsStringSync();
  final match = versionLine.firstMatch(original);
  if (match == null) {
    stderr.writeln('pubspec.yaml has no "version: x.y.z+n" line.');
    exit(65);
  }
  var [major, minor, patch, build] = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
  final from = '$major.$minor.$patch+$build';

  switch (args.firstOrNull) {
    case null:
      break;
    case 'patch':
      patch++;
    case 'minor':
      (minor, patch) = (minor + 1, 0);
    case 'major':
      (major, minor, patch) = (major + 1, 0, 0);
    case final name when RegExp(r'^\d+\.\d+\.\d+$').hasMatch(name):
      [major, minor, patch] = name.split('.').map(int.parse).toList();
    default:
      stderr.writeln('Unknown bump "${args.first}". Use patch | minor | major | x.y.z, or nothing.');
      exit(64);
  }
  final to = '$major.$minor.$patch+${build + 1}';

  stdout.writeln('$from → $to');
  await step('flutter', ['analyze']);
  await step('flutter', ['test']);

  pubspec.writeAsStringSync(original.replaceRange(match.start, match.end, 'version: $to'));
  final code = await run('flutter', [
    'build',
    'appbundle',
    '--release',
    '--dart-define=GHOSTKEY_SERVER_URL=${servers['prod']}',
  ]);
  if (code != 0) {
    pubspec.writeAsStringSync(original);
    stderr.writeln('Build failed; pubspec.yaml is back at $from.');
    exit(code);
  }

  stdout.writeln('\n$to → ${servers['prod']}\n$bundle');
}

Future<void> step(String exe, List<String> args) async {
  final code = await run(exe, args);
  if (code != 0) exit(code);
}

Future<int> run(String exe, List<String> args) async {
  stdout.writeln('\$ $exe ${args.join(' ')}');
  // runInShell so Windows finds flutter.bat.
  final p = await Process.start(exe, args, mode: ProcessStartMode.inheritStdio, runInShell: true);
  return p.exitCode;
}
