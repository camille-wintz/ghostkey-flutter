import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../server/dto/rewards.dart';

/// The cat as the server drew it. The SVG is self-contained — plain hex
/// fills, no CSS functions — so flutter_svg renders it as the desktop does.
class CatPicture extends StatelessWidget {
  const CatPicture(this.cat, {super.key});
  final Cat cat;

  @override
  Widget build(BuildContext context) => SvgPicture.string(cat.svg, semanticsLabel: cat.name);
}
