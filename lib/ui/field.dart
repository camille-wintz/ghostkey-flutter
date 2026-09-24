import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// The house text field: cut into the panel rather than floated on it — the
/// window colour is lighter than the panel's on purpose.
class GkField extends StatelessWidget {
  const GkField({
    super.key,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.obscure = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool autocorrect;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool enabled;

  /// Above 1 the field grows with its text up to [maxLines] and scrolls
  /// after, and a return is a new line rather than a submit.
  final int minLines;
  final int maxLines;

  bool get _multiline => maxLines != 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _multiline ? null : 44,
      decoration: BoxDecoration(
        color: Ds.void_,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: _multiline ? TextInputType.multiline : keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        obscureText: obscure,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        autofillHints: autofillHints,
        cursorColor: Ds.accent,
        textCapitalization: _multiline ? TextCapitalization.sentences : TextCapitalization.none,
        style: DsStyle.ui(DsText.body, color: Ds.hi),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: placeholder,
          hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
        ),
      ),
    );
  }
}
