import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/chat.dart';
import '../../../ui/press.dart';

/// Above the composer when this conversation's tools opened something: the
/// desk seats it beside the chat, the phone opens it here.
class ReviewButton extends StatelessWidget {
  const ReviewButton({super.key, required this.view, required this.onPressed});
  final ChatView view;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Press(
            onPressed: onPressed,
            semanticLabel: 'Review ${reviewTitle(view)}',
            builder: (context, pressed) => AnimatedContainer(
              duration: DsMotion.duration,
              height: DsGeom.ctl,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: pressed ? Ds.veilHi : Ds.veil,
                border: Border.all(color: Ds.edgeHi),
                borderRadius: BorderRadius.circular(DsGeom.radiusRound),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(view.kind), size: 15, color: Ds.accent),
                  const SizedBox(width: 8),
                  Text('Review', style: DsStyle.ui(DsText.ui, color: Ds.hi, weight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      reviewTitle(view),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.ui, color: Ds.mid),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  static IconData _icon(ChatViewKind kind) => switch (kind) {
        ChatViewKind.chapter => LucideIcons.fileText,
        ChatViewKind.board => LucideIcons.layoutGrid,
        ChatViewKind.outline || ChatViewKind.chapters => LucideIcons.listTree,
      };
}

/// What a view is called in a header: its own title, or what it is.
String reviewTitle(ChatView view) => switch (view.title?.trim()) {
      final title? when title.isNotEmpty => title,
      _ => switch (view.kind) {
          ChatViewKind.chapter => 'Chapter',
          ChatViewKind.board => 'Board',
          ChatViewKind.outline => 'Outline',
          ChatViewKind.chapters => 'Chapters',
        },
    };

/// Whether the phone can open what a view names: a chapter and a board need
/// their id; the outline and the chapters are the book's one of each.
bool canReview(ChatView view) => switch (view.kind) {
      ChatViewKind.chapter || ChatViewKind.board => view.id != null,
      ChatViewKind.outline || ChatViewKind.chapters => true,
    };
