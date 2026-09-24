import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../mara/pages.dart';
import '../../../ui/button.dart';
import '../mara_page_screen.dart';

/// No chapters and nothing proposed: where chapters come from.
class ChaptersEmpty extends StatelessWidget {
  const ChaptersEmpty({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
        children: [
          Text('Nothing planned yet.', textAlign: TextAlign.center, style: DsStyle.prose(DsText.prose, color: Ds.hi)),
          const SizedBox(height: 10),
          Text(
            'Chapters come from the plan: write the outline or lay the beats out on a board, then break it into chapters. They are reviewed here, and once made, this is where their notes are kept.',
            textAlign: TextAlign.center,
            style: DsStyle.ui(DsText.ui, color: Ds.mid),
          ),
          const SizedBox(height: 22),
          Center(child: GkButton(label: 'Outline', onPressed: () => openMaraPage(context, MaraPage.outline))),
          const SizedBox(height: 10),
          Center(
            child: GkButton(label: 'Cards', variant: ButtonVariant.outline, onPressed: () => openMaraPage(context, MaraPage.cards)),
          ),
        ],
      );
}
