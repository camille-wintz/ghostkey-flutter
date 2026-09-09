import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/welcome_notices.dart';
import '../../auth/session.dart';
import '../../ds/tokens.dart';
import '../../server/auth/api.dart';
import '../../server/errors.dart';
import '../../server/secure_storage.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'forgot_password_form.dart';

/// The two panes with a form, and the third you can only reach from the
/// first — asking for a reset link is somewhere you go, never somewhere you
/// arrive, so it gets no tab.
enum _Mode { signin, signup, forgot }

const Map<_Mode, String> _blurb = {
  _Mode.signin: 'Sign in to sync your projects.',
  _Mode.signup: 'Create an account to sync your projects.',
  _Mode.forgot: 'Reset your password.',
};

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _Mode _mode = _Mode.signin;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(_refresh);
    _password.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_pending &&
      _email.text.trim().isNotEmpty &&
      _password.text.length >= (_mode == _Mode.signup ? 8 : 1);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    final email = _email.text.trim();
    final password = _password.text;
    try {
      final session = _mode == _Mode.signin
          ? await postSignin(email, password)
          : await postSignup(email, password);
      // Registering is the only moment the welcome-week greeting may fire,
      // and nothing downstream can tell a fresh account from a returning one.
      if (_mode == _Mode.signup) rememberSignupArrival();
      await ref.read(sessionProvider.notifier).setSession(
            session,
            credentials: StoredCredentials(email: email, password: password),
          );
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _switch(_Mode next) => setState(() {
        _mode = next;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandTitle('GhostKey.AI', align: TextAlign.center),
              const SizedBox(height: 10),
              UiText(_blurb[_mode]!, color: Ds.mid, align: TextAlign.center),
              const SizedBox(height: 32),
              if (_mode == _Mode.forgot)
                ForgotPasswordForm(
                  email: _email,
                  onBack: () => _switch(_Mode.signin),
                )
              else ...[
                _ModeTabs(mode: _mode, onChange: _switch),
                const SizedBox(height: 24),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GkField(
                        controller: _email,
                        placeholder: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 10),
                      GkField(
                        controller: _password,
                        placeholder: _mode == _Mode.signup ? 'Password (at least 8 characters)' : 'Password',
                        obscure: true,
                        autocorrect: false,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _submit(),
                        autofillHints: [
                          _mode == _Mode.signup ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  UiText(_error!, step: DsText.ui, color: Ds.destructive),
                  const SizedBox(height: 12),
                ],
                GkButton(
                  label: _mode == _Mode.signin ? 'Sign In' : 'Create Account',
                  wide: true,
                  busy: _pending,
                  disabled: !_canSubmit && !_pending,
                  onPressed: _submit,
                ),
                if (_mode == _Mode.signin)
                  Press(
                    onPressed: () => _switch(_Mode.forgot),
                    builder: (context, pressed) => Opacity(
                      opacity: pressed ? 0.6 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: UiText('Forgot password?', step: DsText.ui, color: Ds.low, align: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChange});
  final _Mode mode;
  final ValueChanged<_Mode> onChange;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            _Tab(label: 'Sign In', active: mode == _Mode.signin, onPressed: () => onChange(_Mode.signin)),
            _Tab(label: 'Sign Up', active: mode == _Mode.signup, onPressed: () => onChange(_Mode.signup)),
          ],
        ),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onPressed});
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Press(
          onPressed: onPressed,
          builder: (context, pressed) => AnimatedContainer(
            duration: DsMotion.duration,
            height: DsGeom.ctl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Ds.accentMix(14) : (pressed ? Ds.veil : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(DsGeom.radius - 4),
            ),
            child: Text(
              label,
              style: DsStyle.ui(
                DsText.ui,
                color: active ? Ds.accent : Ds.mid,
                weight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
}
