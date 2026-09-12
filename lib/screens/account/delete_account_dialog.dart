import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/notice_modal.dart';
import '../../ui/text.dart';

const _word = 'DELETE';

/// Deleting the account, asked twice: once to say what goes, once to type the
/// word. Resolves true only when both were answered yes — the delete itself is
/// the caller's.
Future<bool> confirmDeleteAccount(
  BuildContext context, {
  required String email,
  required bool hasLiveSubscription,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xC708060D),
    builder: (context) => Dialog(
      backgroundColor: const Color(0x00000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: _DeleteAccountSteps(email: email, hasLiveSubscription: hasLiveSubscription),
    ),
  );
  return confirmed ?? false;
}

class _DeleteAccountSteps extends StatefulWidget {
  const _DeleteAccountSteps({required this.email, required this.hasLiveSubscription});
  final String email;
  final bool hasLiveSubscription;

  @override
  State<_DeleteAccountSteps> createState() => _DeleteAccountStepsState();
}

class _DeleteAccountStepsState extends State<_DeleteAccountSteps> {
  final _typed = TextEditingController();
  bool _warned = false;

  bool get _matches => _typed.text.trim() == _word;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _keep() => Navigator.of(context).pop(false);

  void _delete() {
    if (_matches) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Eyebrow('Delete account', color: Ds.destructive),
          const SizedBox(height: 4),
          BrandTitle(_warned ? 'This can\'t be undone' : 'Delete your account?', size: BrandTitleSize.chrome),
          const SizedBox(height: 10),
          if (!_warned) ...[
            NoticeText(
              'Deleting ${widget.email} removes every book, chapter, note, world bible, board, chat and '
              'image on it, from the server and from every device, straight away. There is no grace '
              'period and no way to get any of it back.',
            ),
            if (widget.hasLiveSubscription) ...[
              const SizedBox(height: 8),
              const NoticeText('Your subscription ends today too, and the rest of the period isn\'t refunded.'),
            ],
          ] else ...[
            NoticeText('Type $_word to delete ${widget.email} and everything in it.'),
            const SizedBox(height: 12),
            GkField(
              controller: _typed,
              placeholder: _word,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _delete(),
            ),
          ],
          const SizedBox(height: 16),
          _warned
              ? GkButton(
                  label: 'Delete account',
                  variant: ButtonVariant.destructive,
                  wide: true,
                  disabled: !_matches,
                  onPressed: _delete,
                )
              : GkButton(label: 'Continue', variant: ButtonVariant.outline, wide: true, onPressed: () => setState(() => _warned = true)),
          const SizedBox(height: 10),
          GkButton(label: 'Keep my account', wide: true, onPressed: _keep),
        ],
      ),
    );
  }
}
