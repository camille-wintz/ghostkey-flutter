import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/offline/mirror.dart';
import 'package:ghostkey/server/errors.dart';

void main() {
  late Directory root;
  late String stamp;
  late String? user;

  Mirror make() => Mirror(root: () async => root, buildStamp: () async => stamp, userId: () => user);

  Never offline() => throw ServerError('network_error', 0);

  setUp(() {
    root = Directory('${Directory.systemTemp.createTempSync('ghostkey-mirror').path}/mirror');
    stamp = 'build-1';
    user = 'u1';
  });

  tearDown(() => root.parent.delete(recursive: true));

  test('online answers are kept and served when the server cannot be reached', () async {
    final mirror = make();
    expect(await mirror.readThrough('project:p', () async => {'name': 'Book'}), {'name': 'Book'});
    expect(await mirror.readThrough('project:p', () async => offline()), {'name': 'Book'});
  });

  test('offline with nothing held, and any refusal from the server, still throw', () async {
    final mirror = make();
    await expectLater(mirror.readThrough('project:p', () async => offline()), throwsA(isA<ServerError>()));
    await mirror.readThrough('project:p', () async => {'name': 'Book'});
    await expectLater(
      mirror.readThrough('project:p', () async => throw ServerError('not_found', 404)),
      throwsA(isA<ServerError>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test('a late answer never replaces a newer revision', () async {
    final mirror = make();
    await mirror.remember('document:p:d', {'content': 'saved', 'version': 3}, version: 3);
    await mirror.readThrough('document:p:d', () async => {'content': 'stale', 'version': 2}, version: (j) => j['version'] as int);
    expect((await mirror.readThrough('document:p:d', () async => offline()))['content'], 'saved');
  });

  test('copies belong to the account that fetched them', () async {
    final mirror = make();
    await mirror.readThrough('projects:root', () async => {'projects': ['mine']});
    user = 'u2';
    await expectLater(mirror.readThrough('projects:root', () async => offline()), throwsA(isA<ServerError>()));
  });

  test('sign-out wipes every copy', () async {
    final mirror = make();
    await mirror.readThrough('projects:root', () async => {'projects': <String>[]});
    await mirror.wipe();
    await expectLater(mirror.readThrough('projects:root', () async => offline()), throwsA(isA<ServerError>()));
  });

  test('a new build of the app starts with no copies', () async {
    await make().readThrough('projects:root', () async => {'projects': <String>[]});
    expect(await make().readThrough('projects:root', () async => offline()), {'projects': <String>[]});
    stamp = 'build-2';
    await expectLater(make().readThrough('projects:root', () async => offline()), throwsA(isA<ServerError>()));
  });
}
