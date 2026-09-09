import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/auth/api.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// Ask for a reset link, from the sign-in screen. The email belongs to the
/// caller — it is usually already typed into the sign-in field, and turning
/// back has to find it still there. The link in the mail opens the web app;
/// the author sets the password there and comes back to sign in with it.
class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({super.key, required this.email, required this.onBack});
  final TextEditingController email;
  final VoidCallback onBack;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  bool _pending = false;
  String? _error;

  /// The address as it was when it went out, so the confirmation keeps
  /// naming that one even if the field is edited behind it.
  String? _sentTo;

  Future<void> _submit() async {
    final trimmed = widget.email.text.trim();
    if (trimmed.isEmpty || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await postForgotPassword(trimmed);
      if (mounted) setState(() => _sentTo = trimmed);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    if (sentTo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText('Check your email', weight: FontWeight.w600, color: Ds.hi, align: TextAlign.center),
          const SizedBox(height: 16),
          UiText(
            'If $sentTo has an account, a link to set a new password is on its way. '
            'It opens in your browser, works once, and expires in an hour.',
            step: DsText.ui,
            color: Ds.mid,
            align: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GkButton(label: 'Back to Sign In', wide: true, onPressed: widget.onBack),
          _Link('Use a different address', onPressed: () => setState(() => _sentTo = null)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiText(
          "Enter the address you signed up with and we'll send a link to set a new password.",
          step: DsText.ui,
          color: Ds.mid,
        ),
        const SizedBox(height: 16),
        GkField(
          controller: widget.email,
          placeholder: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofocus: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          UiText(_error!, step: DsText.ui, color: Ds.destructive),
          const SizedBox(height: 12),
        ],
        GkButton(label: 'Send Reset Link', wide: true, busy: _pending, onPressed: _submit),
        _Link('Back to Sign In', onPressed: widget.onBack),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, {required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: UiText(label, step: DsText.ui, color: Ds.low, align: TextAlign.center),
          ),
        ),
      );
}
