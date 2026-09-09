import 'package:flutter/widgets.dart';

import '../ds/tokens.dart';

/// The brand's voice in a heading: Newsreader, semibold, on the brightest ink.
/// Titles sound like a book; the app's own words do not.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.text, {super.key, this.size = BrandTitleSize.page, this.align});
  final String text;
  final BrandTitleSize size;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final step = switch (size) {
      BrandTitleSize.hero => DsText.display,
      BrandTitleSize.page => const DsStep(32, 38),
      BrandTitleSize.chrome => DsText.prose,
      BrandTitleSize.compact => DsText.body,
    };
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: align,
        style: DsStyle.prose(step, weight: FontWeight.w600),
      ),
    );
  }
}

enum BrandTitleSize { hero, page, chrome, compact }

/// The uppercase eyebrow every section is titled with.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.semibold = true});
  final String text;
  final Color? color;
  final bool semibold;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DsStyle.eyebrow(
          color: color,
          weight: semibold ? FontWeight.w600 : FontWeight.w400,
        ),
      );
}

/// A body line in the app's own words.
class UiText extends StatelessWidget {
  const UiText(
    this.text, {
    super.key,
    this.step = DsText.body,
    this.color,
    this.weight = FontWeight.w400,
    this.align,
    this.maxLines,
  });
  final String text;
  final DsStep step;
  final Color? color;
  final FontWeight weight;
  final TextAlign? align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: DsStyle.ui(step, color: color, weight: weight),
      );
}
