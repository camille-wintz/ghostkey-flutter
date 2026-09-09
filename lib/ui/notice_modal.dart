import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'button.dart';

/// The shell the notices share: a dimmed page, a card that grows with its
/// content, an eyebrow, a title and one dismiss button. Mobile sells nothing,
/// so there is never a second, competing action.
Future<void> showNoticeModal(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String action,
  required List<Widget> children,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xC708060D),
    builder: (context) => Dialog(
      backgroundColor: const Color(0x00000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 2, color: Ds.accent),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(eyebrow.toUpperCase(), style: DsStyle.eyebrow(color: Ds.accent)),
                      const SizedBox(height: 14),
                      Text(title, style: DsStyle.prose(DsText.title, weight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      ...children.expand((c) => [c, const SizedBox(height: 14)]),
                      GkButton(label: action, wide: true, onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A body paragraph, in the notices' one voice.
class NoticeText extends StatelessWidget {
  const NoticeText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: DsStyle.ui(DsText.body, color: Ds.mid));
}

/// One bulleted line of what a plan opens.
class NoticeBullet extends StatelessWidget {
  const NoticeBullet(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: BoxDecoration(color: Ds.accent, shape: BoxShape.circle),
          ),
          Expanded(child: Text(text, style: DsStyle.ui(DsText.ui, color: Ds.mid))),
        ],
      );
}
