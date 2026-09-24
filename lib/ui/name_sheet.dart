import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'button.dart';
import 'field.dart';
import 'sheet.dart';

/// A name typed into a sheet. Resolves with the trimmed text as submitted —
/// unchanged, or empty when [allowEmpty] (a name that falls back to something
/// when cleared) — and null only when the sheet is closed. [message] says,
/// above the field, what the name is for.
Future<String?> showNameSheet(
  BuildContext context, {
  required String eyebrow,
  required String current,
  required String action,
  String? message,
  String? placeholder,
  int? maxLength,
  bool allowEmpty = false,
}) =>
    showGkSheet<String>(
      context,
      header: SheetHeader(eyebrow: eyebrow, onClose: () => Navigator.of(context).pop()),
      builder: (context) => _NameForm(
        current: current,
        message: message,
        action: action,
        placeholder: placeholder,
        maxLength: maxLength,
        allowEmpty: allowEmpty,
      ),
    );

class _NameForm extends StatefulWidget {
  const _NameForm({
    required this.current,
    required this.message,
    required this.action,
    required this.placeholder,
    required this.maxLength,
    required this.allowEmpty,
  });
  final String current;
  final String? message;
  final String action;
  final String? placeholder;
  final int? maxLength;
  final bool allowEmpty;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final TextEditingController _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _name.text.trim();
    if (next.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message case final message?) ...[
              Text(message, style: DsStyle.ui(DsText.body, color: Ds.mid)),
              const SizedBox(height: 14),
            ],
            GkField(
              controller: _name,
              placeholder: widget.placeholder,
              maxLength: widget.maxLength,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            GkButton(label: widget.action, wide: true, onPressed: _submit),
          ],
        ),
      );
}
