import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/errors.dart';
import '../../share/share_file.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import '../../veil/id_card/id_card.dart';
import '../../veil/id_card/render_id_card.dart';

/// A character's ID card, ready to send out: the picture as it will leave,
/// the line under the name still being written or ready, in a field the
/// author can rewrite, another line on request, and the phone's own share
/// sheet. The card is drawn without its line first, so there is something to
/// look at while the joke is written. The phone web's `IdCardSheet.tsx`.
///
/// No Download: the share sheet is the way out, and saving to the gallery
/// would be a second plugin and, on older Androids, a storage permission.
Future<void> showIdCardSheet(BuildContext context, IdCard card) {
  card.start();
  return showGkSheet<void>(
    context,
    maxHeightFraction: 0.9,
    builder: (context) => _IdCardSheet(card: card),
  );
}

class _IdCardSheet extends StatefulWidget {
  const _IdCardSheet({required this.card});
  final IdCard card;

  @override
  State<_IdCardSheet> createState() => _IdCardSheetState();
}

class _IdCardSheetState extends State<_IdCardSheet> {
  late final _text = TextEditingController(text: widget.card.line);
  bool _sharing = false;
  String? _shareError;

  @override
  void initState() {
    super.initState();
    widget.card.addListener(_follow);
  }

  @override
  void dispose() {
    widget.card.removeListener(_follow);
    _text.dispose();
    super.dispose();
  }

  /// A line from the model lands in the field; the author's own typing is
  /// already there, and setting it back would move the caret.
  void _follow() {
    if (_text.text != widget.card.line) _text.text = widget.card.line;
  }

  Future<void> _share() async {
    final png = widget.card.png;
    if (png == null || _sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await shareFile(png, name: widget.card.fileName);
    } catch (e) {
      debugPrint('[idCard] share failed: $e');
      if (mounted) setState(() => _shareError = messageFor(e));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(eyebrow: 'ID card', onClose: () => Navigator.of(context).pop()),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: ListenableBuilder(
                listenable: widget.card,
                builder: (context, _) {
                  final card = widget.card;
                  final writing = card.tagline == TaglineState.writing;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: idCardAspect,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Ds.raise,
                            border: Border.all(color: Ds.edge),
                            borderRadius: BorderRadius.circular(DsGeom.radius),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: card.png != null
                              ? Image.memory(
                                  card.png!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  semanticLabel: 'The ID card',
                                )
                              : SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Ds.low),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            if (writing) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Ds.low),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: UiText('Writing a line for the card…', step: DsText.ui, color: Ds.low)),
                            ] else if (card.tagline == TaglineState.failed && card.error != null)
                              Expanded(child: UiText(card.error!, step: DsText.ui, color: Ds.attention300)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GkField(
                        controller: _text,
                        placeholder: 'Write your own line',
                        enabled: !writing,
                        maxLength: taglineMax,
                        textInputAction: TextInputAction.done,
                        onChanged: card.edit,
                      ),
                      const SizedBox(height: 16),
                      GkButton(
                        label: 'Change line',
                        variant: ButtonVariant.outline,
                        wide: true,
                        busy: writing,
                        leading: Icon(LucideIcons.refreshCw, size: 16, color: Ds.soft),
                        onPressed: card.another,
                      ),
                      const SizedBox(height: 10),
                      if (_shareError case final error?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: UiText(error, step: DsText.ui, color: Ds.destructive),
                        ),
                      GkButton(
                        label: 'Share',
                        wide: true,
                        busy: _sharing,
                        disabled: !card.ready,
                        leading: Icon(LucideIcons.share2, size: 16, color: Ds.accent),
                        onPressed: _share,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      );
}
