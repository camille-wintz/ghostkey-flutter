import 'dart:math';

final Random _random = Random.secure();

/// A v4 uuid, for the client-minted ids the plan rows and tasks carry. No
/// package: sixteen random bytes with the version and variant bits set.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The clock every plan and task write stamps with, as the desktop does.
String nowIso() => DateTime.now().toUtc().toIso8601String();
