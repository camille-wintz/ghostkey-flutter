import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/gift.dart';
import '../../server/errors.dart';
import '../../server/gift/api.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// The signup form's gift code, behind a quiet "Have a gift code?" so the
/// form does not ask everybody for something most people don't have. Once
/// the code is whole (eight characters) the server says what it gives, or
/// why it gives nothing — the same check the desk's signup page makes.
class GiftCodeField extends StatefulWidget {
  const GiftCodeField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<GiftCodeField> createState() => _GiftCodeFieldState();
}

class _GiftCodeFieldState extends State<GiftCodeField> {
  late bool _open = widget.controller.text.isNotEmpty;
  String _checked = '';
  GiftOffer? _offer;
  String? _refusal;

  static const _codeRefusals = {'unknown_gift_code', 'gift_code_taken', 'gift_inactive'};

  static String _normalize(String code) => code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _check(String typed) async {
    final code = _normalize(typed);
    if (code == _checked) return;
    _checked = code;
    setState(() {
      _offer = null;
      _refusal = code.length > 8 ? messageFor(ServerError('unknown_gift_code', 404)) : null;
    });
    if (code.length != 8) return;
    try {
      final offer = await checkGiftCode(code);
      if (mounted && _checked == code) setState(() => _offer = offer);
    } on ServerError catch (e) {
      if (!mounted || _checked != code) return;
      if (_codeRefusals.contains(e.code)) setState(() => _refusal = messageFor(e));
    } catch (e) {
      // Offline or the server hiccuped: say nothing, and let the signup
      // itself be the check — it refuses a bad code by name.
      debugPrint('[gift_code_field] could not check the code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Press(
        onPressed: () => setState(() => _open = true),
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: UiText('Have a gift code?', step: DsText.ui, color: Ds.low),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GkField(
          controller: widget.controller,
          placeholder: 'Gift code (optional)',
          autocorrect: false,
          onChanged: _check,
        ),
        if (_offer case final offer?) ...[
          const SizedBox(height: 6),
          UiText(
            "A friend's gift — this code gives you ${offer.plan.displayName} as soon as you sign up.",
            step: DsText.ui,
            color: Ds.done,
          ),
        ],
        if (_refusal case final refusal?) ...[
          const SizedBox(height: 6),
          UiText(refusal, step: DsText.ui, color: Ds.destructive),
        ],
      ],
    );
  }
}
