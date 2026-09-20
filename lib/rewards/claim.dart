import 'dart:async';

import 'package:flutter/foundation.dart';

import '../server/dto/rewards.dart';
import '../server/rewards/api.dart';

/// The autosave lands every few seconds while the author types; the server
/// is idempotent, so a claim every few seconds sees the same milestones.
const Duration _throttle = Duration(seconds: 3);

/// Ask the server what today's writing has earned, and show it — the one
/// door for any surface that writes prose the server banks. Call [saved]
/// after a write lands; it throttles itself and always makes a trailing
/// call, so the last words of a session are counted. The server decides
/// every reward, and they are the author's: a claim from any book counts
/// every book's words. This only shows what it says.
class RewardClaimer {
  RewardClaimer({required this.onAwarded});

  /// A claim that awarded something — the awards in order, and where today
  /// stands, which is what the card puts them against.
  final void Function(RewardClaim claim) onAwarded;

  DateTime? _lastAt;
  Timer? _pending;

  void saved() {
    final since = _lastAt == null ? _throttle : DateTime.now().difference(_lastAt!);
    if (since >= _throttle && _pending == null) {
      unawaited(_claim());
      return;
    }
    if (_pending != null) return;
    _pending = Timer(_throttle - since, () {
      _pending = null;
      unawaited(_claim());
    });
  }

  Future<void> _claim() async {
    _lastAt = DateTime.now();
    try {
      final claim = await claimMyRewards();
      if (claim.awarded.isNotEmpty) onAwarded(claim);
    } catch (e) {
      // Decorative: a reward that fails to show is claimed again on the next
      // save, and the save itself is not in question.
      debugPrint('[rewards] claim failed: $e');
    }
  }

  void dispose() {
    _pending?.cancel();
    _pending = null;
  }
}
