import 'dart:async';

import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import '../poltergeist/rewards.dart';
import '../server/dto/rewards.dart';
import '../server/rewards/api.dart';
import 'cat_picture.dart';

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

  /// Everything one claim awarded, in order, to be shown.
  final void Function(List<Reward> awarded) onAwarded;

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
      if (claim.awarded.isNotEmpty) onAwarded(claim.awarded);
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

/// One reward as a passing notice at the foot of the screen — the phone's
/// toast. Queued, so two awarded in one claim show one after the other.
void showRewardNotice(BuildContext context, Reward reward) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (text, detail) = rewardWords(reward);
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Ds.panel,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Ds.edge)),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reward is CatReward)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(width: 40, height: 40, child: CatPicture(reward.cat)),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: DsStyle.ui(DsText.ui, color: Ds.hi)),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(detail, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
