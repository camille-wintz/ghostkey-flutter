import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../ds/tokens.dart';
import '../../server/auth/api.dart';
import '../../server/errors.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// What to do about an unverified address. The verification email carries a
/// link, so there is nothing to type here — this only sends another one and
/// notices when the browser has done its part.
///
/// The lock counts down whatever the SERVER said, on both the accepted and
/// the refused answer — never a local 60.
class VerifyEmailNotice extends ConsumerStatefulWidget {
  const VerifyEmailNotice({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailNotice> createState() => _VerifyEmailNoticeState();
}

class _VerifyEmailNoticeState extends ConsumerState<VerifyEmailNotice> {
  int _secondsLeft = 0;
  bool _pending = false;
  bool _rechecking = false;
  bool _sent = false;
  String? _error;
  Timer? _timer;
  DateTime _deadline = DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClock(int seconds) {
    _deadline = DateTime.now().add(Duration(seconds: seconds));
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final left = (_deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft = left > 0 ? left : 0);
      if (left <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_pending || _secondsLeft > 0) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final result = await postResendVerification();
      _startClock(result.retryAfter);
      if (result.sent) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  /// Rotating the session is how the account is re-read: `email_verified`
  /// rides the refresh response.
  Future<void> _recheck() async {
    final token = ref.read(sessionProvider).refreshToken;
    if (token == null) return;
    setState(() {
      _rechecking = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).setSession(await postRefresh(token));
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _pending || _secondsLeft > 0;
    final label = _pending
        ? 'Sending…'
        : _secondsLeft > 0
            ? 'Send again in ${_secondsLeft}s'
            : _sent
                ? 'Send another'
                : 'Send it again';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Confirm your email', color: Ds.accent),
          const SizedBox(height: 10),
          UiText(
            _sent
                ? 'Sent. Open the link in the email we just sent to ${widget.email} — nothing to type back here.'
                : "We sent a link to ${widget.email}. Opening it confirms the address; you'll need it for password resets and receipts.",
            step: DsText.ui,
            color: Ds.mid,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            UiText(_error!, step: DsText.ui, color: Ds.destructive),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Press(
                onPressed: _resend,
                enabled: !locked,
                builder: (context, pressed) => Opacity(
                  opacity: locked ? 0.45 : (pressed ? 0.7 : 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Ds.accentMix(12),
                      border: Border.all(color: Ds.accentMix(55)),
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                    ),
                    child: UiText(label, step: DsText.ui, color: Ds.hi, weight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Press(
                onPressed: _recheck,
                enabled: !_rechecking,
                builder: (context, pressed) =>
                    UiText(_rechecking ? 'Checking…' : 'Already clicked it?', step: DsText.ui, color: Ds.low),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
