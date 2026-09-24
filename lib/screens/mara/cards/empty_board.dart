import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/button.dart';

/// A board with nothing on it says so, and offers the ways to start: adding
/// the first card, and — on a structure, with a book to read — filling it.
class EmptyBoard extends StatelessWidget {
  const EmptyBoard({super.key, required this.onAddCard, this.onFill});
  final VoidCallback onAddCard;

  /// Null when the fill is not offered here.
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 40),
        children: [
          Text('Nothing on this board yet.', textAlign: TextAlign.center, style: DsStyle.prose(DsText.prose, color: Ds.hi)),
          const SizedBox(height: 10),
          Text(
            'Each card is one thing that happens. Put them in the order they read, and add a label wherever a part of the book starts.',
            textAlign: TextAlign.center,
            style: DsStyle.ui(DsText.ui, color: Ds.mid),
          ),
          const SizedBox(height: 22),
          Center(child: GkButton(label: 'Add the first card', onPressed: onAddCard)),
          if (onFill case final onFill?) ...[
            const SizedBox(height: 10),
            Center(child: GkButton(label: 'Fill from your book', variant: ButtonVariant.outline, onPressed: onFill)),
          ],
        ],
      );
}
