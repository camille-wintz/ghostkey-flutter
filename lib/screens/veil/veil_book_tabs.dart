import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';

/// Which book of the series the roster is measured against. Selecting one
/// re-scales every count and bar beside a name, so this answers "how present
/// is this cast in book two", not only "which of them are in it". The book
/// being viewed reads "This one" — its title is already in the header.
class VeilBookTabs extends StatelessWidget {
  const VeilBookTabs({
    super.key,
    required this.books,
    required this.value,
    required this.projectId,
    required this.onChange,
  });

  final List<BookTab> books;

  /// Null is the "All" pill.
  final String? value;
  final String projectId;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Eyebrow('Book', semibold: false),
          ),
          _Pill(label: 'All', active: value == null, onTap: () => onChange(null)),
          for (final book in books)
            _Pill(
              label: book.id == projectId ? 'This one' : book.label,
              active: value == book.id,
              onTap: () => onChange(book.id),
            ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
            border: Border.all(color: active ? Ds.accentMix(25) : (pressed ? Ds.edgeHi : Ds.edge)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsStyle.ui(DsText.ui, color: active ? Ds.accent200 : Ds.low),
          ),
        ),
      );
}
