import 'package:flutter/material.dart';

import '../../mara/pages.dart';
import 'cards/cards_page.dart';
import 'chapters/chapters_page.dart';
import 'outline/outline_page.dart';

/// Push one of Mara's pages, full screen, over whatever is showing — the
/// room's list, or another page that points at it (a proposal's Review, the
/// empty Chapters page's doors, a chat review).
Future<void> openMaraPage(BuildContext context, MaraPage page) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (page) {
          MaraPage.outline => const OutlinePage(),
          MaraPage.cards => const CardsPage(),
          MaraPage.chapters => const ChaptersPage(),
        },
      ),
    );
