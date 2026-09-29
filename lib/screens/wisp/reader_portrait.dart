import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';

/// A beta reader's cat, as the catalogue drew it, in a round frame. The SVG
/// is self-contained, as `CatPicture`'s is.
class ReaderPortrait extends StatelessWidget {
  const ReaderPortrait({super.key, required this.reader, this.size = 64});
  final ReaderCard reader;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Ds.catFrame, border: Border.all(color: Ds.edgeHi)),
        child: ClipOval(child: SvgPicture.string(reader.picture, semanticsLabel: reader.name)),
      );
}
