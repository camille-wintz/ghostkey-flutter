import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/text.dart';
import 'veil_nightscape.dart';

/// Veil before anything has been filed: the room's one screen, the desktop's
/// `BibleEmptyState` in a phone's width. Whole-screen rather than a card,
/// because an empty state framed inside an empty page reads as a page that
/// failed to load.
///
/// Two doors where the desk has three: importing a bible is a desk move, so
/// the copy names it rather than the screen offering a door that goes
/// nowhere. Writing an entry by hand needs no manuscript, so it is offered
/// even to a book with no chapters.
class VeilEmptyState extends StatelessWidget {
  const VeilEmptyState({
    super.key,
    required this.hasChapters,
    required this.running,
    required this.onGenerate,
    required this.onAdd,
  });

  /// False when the book has no chapters yet — there is nothing to read.
  final bool hasChapters;
  final bool running;
  final VoidCallback onGenerate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(20, 32, 20, 40 + MediaQuery.paddingOf(context).bottom);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - padding.vertical),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow('World bible', semibold: false),
              const SizedBox(height: 12),
              const BrandTitle('Worldbuilding'),
              const SizedBox(height: 14),
              Text(
                'The characters, places and lore your book keeps track of. Let Ghostkey find them in the '
                'manuscript, write them in yourself — or, on the desktop, bring in a bible you already keep.',
                style: DsStyle.ui(DsText.body, color: Ds.mid),
              ),
              const SizedBox(height: 32),
              Container(height: 1, color: Ds.edge),
              const SizedBox(height: 32),
              const VeilNightscape(),
              const SizedBox(height: 32),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (hasChapters) GkButton(label: 'Analyze your world', onPressed: onGenerate, busy: running),
                  GkButton(
                    label: 'Add character',
                    variant: hasChapters ? ButtonVariant.outline : ButtonVariant.primary,
                    onPressed: onAdd,
                  ),
                ],
              ),
              if (!hasChapters) ...[
                const SizedBox(height: 14),
                Text(
                  'Analyzing needs a chapter first — the bible is read from what you have written.',
                  style: DsStyle.ui(DsText.ui, color: Ds.low),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
