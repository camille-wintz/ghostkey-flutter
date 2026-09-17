import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// The one question a Google sign-in can come back with: this address already
/// has an account here, and it never confirmed the address — so Google's word
/// on who owns the inbox does not yet say whose account it is. Its password
/// does. The screen holds the Google token; this adds the password.
class GoogleLinkForm extends StatefulWidget {
  const GoogleLinkForm({
    super.key,
    required this.onSubmit,
    required this.onBack,
    required this.pending,
    this.error,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final bool pending;
  final String? error;

  @override
  State<GoogleLinkForm> createState() => _GoogleLinkFormState();
}

class _GoogleLinkFormState extends State<GoogleLinkForm> {
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isNotEmpty && !widget.pending) widget.onSubmit(_password.text);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'You already have a Ghostkey account with this address, made with a password. '
            'Enter that password once and Google will open the same account from now on.',
            color: Ds.mid,
          ),
          const SizedBox(height: 16),
          GkField(
            controller: _password,
            placeholder: 'Your Ghostkey password',
            obscure: true,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submit(),
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 16),
          if (widget.error != null) ...[
            UiText(widget.error!, step: DsText.ui, color: Ds.destructive),
            const SizedBox(height: 12),
          ],
          GkButton(
            label: 'Connect Google',
            wide: true,
            busy: widget.pending,
            disabled: _password.text.isEmpty && !widget.pending,
            onPressed: _submit,
          ),
          Press(
            onPressed: widget.onBack,
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.6 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: UiText('Back to sign in', step: DsText.ui, color: Ds.low, align: TextAlign.center),
              ),
            ),
          ),
        ],
      );
}
