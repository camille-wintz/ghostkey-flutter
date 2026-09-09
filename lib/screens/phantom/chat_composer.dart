import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// Multiline input · attach-chapter · send (or stop while a turn runs). Paste
/// interception is the formatter's business; this only hosts it. Pinned
/// above the keyboard by the Scaffold, and above the system bar at rest by
/// its own SafeArea.
class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.pasteInterceptor,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.sending,
    required this.canSend,
  });

  final TextEditingController controller;
  final TextInputFormatter pasteInterceptor;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final bool sending;

  /// Text or an attachment to send.
  final bool canSend;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border(top: BorderSide(color: Ds.edge)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoundButton(onPressed: onAttach, label: 'Attach a chapter', icon: LucideIcons.paperclip, tone: _Tone.quiet),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    inputFormatters: [pasteInterceptor],
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    autocorrect: true,
                    cursorColor: Ds.accent,
                    style: DsStyle.ui(DsText.body, color: Ds.hi),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Ds.void_,
                      hintText: 'Ask about your book…',
                      hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: _border(Ds.edge),
                      focusedBorder: _border(Ds.edgeHi),
                      border: _border(Ds.edge),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (sending)
                  _RoundButton(onPressed: onStop, label: 'Stop', icon: LucideIcons.square, tone: _Tone.destructive)
                else
                  _RoundButton(
                    onPressed: onSend,
                    label: 'Send',
                    icon: LucideIcons.arrowUp,
                    tone: _Tone.accent,
                    disabled: !canSend,
                  ),
              ],
            ),
          ),
        ),
      );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(DsGeom.radius),
        borderSide: BorderSide(color: color),
      );
}

enum _Tone { accent, destructive, quiet }

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.tone,
    this.disabled = false,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final _Tone tone;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final filled = tone != _Tone.quiet;
    final fill = switch (tone) {
      _Tone.accent => Ds.accent,
      _Tone.destructive => Ds.destructive,
      _Tone.quiet => const Color(0x00000000),
    };
    return Press(
      onPressed: onPressed,
      enabled: !disabled,
      semanticLabel: label,
      hitSlop: 4,
      builder: (context, pressed) => AnimatedOpacity(
        duration: DsMotion.duration,
        opacity: disabled ? 0.35 : (pressed ? 0.75 : 1),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: filled ? 18 : 20, color: filled ? Ds.void_ : Ds.mid),
        ),
      ),
    );
  }
}
