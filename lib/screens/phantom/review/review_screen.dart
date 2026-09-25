import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/chat.dart';
import '../../../ui/room_title_bar.dart';
import '../../mara/chapters/chapters_view.dart';
import 'board_review.dart';
import 'chapter_review.dart';
import 'image_review.dart';
import 'outline_review.dart';
import 'review_button.dart';

/// What a conversation's tools opened, as a page pushed over the chat: a
/// board, the outline, the chapters — Mara's own pages — a chapter's line
/// edits to rule on, or a picture from the library.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.projectId, required this.view});
  final String projectId;
  final ChatView view;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Ds.void_,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              RoomTitleBar(title: reviewTitle(view), onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: switch (view.kind) {
                  ChatViewKind.board => BoardReview(projectId: projectId, boardId: view.id!),
                  ChatViewKind.outline => OutlineReview(projectId: projectId),
                  ChatViewKind.chapter => ChapterReview(projectId: projectId, documentId: view.id!),
                  ChatViewKind.chapters => ChaptersView(projectId: projectId),
                  ChatViewKind.image => ImageReview(projectId: projectId, itemId: view.id!, headerTitle: reviewTitle(view)),
                },
              ),
            ],
          ),
        ),
      );
}
