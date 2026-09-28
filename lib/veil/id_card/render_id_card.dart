import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../ds/tokens.dart';

/// What a card says: the name, and the line under it — empty while it is
/// still being written.
class IdCardFace {
  const IdCardFace({required this.name, required this.tagline});
  final String name;
  final String tagline;
}

const double idCardWidth = 1600;
const double idCardHeight = 800;
const double idCardAspect = idCardWidth / idCardHeight;
const double _pad = 64;
const double _portraitW = 460;
const double _portraitH = idCardHeight - _pad * 2;
const double _gap = 72;

/// A world-bible card drawn as an identity card — the picture an author
/// shares out of the app. Canvas only, no widgets: it takes the words already
/// composed and the portrait's bytes, and answers a PNG.
///
/// The desk's `renderIdCard.ts` drawn again, measure for measure: portrait on
/// the left, the name and the line centred beside it, the line in italics
/// behind an accent bar. Colours are the `Ds` tokens and the face is the
/// book's own (Newsreader) — the phone is night only, so the card is too.
Future<Uint8List> renderIdCard(IdCardFace face, Uint8List? portrait) async {
  final image = portrait == null ? null : await _decode(portrait);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, idCardWidth, idCardHeight));

  // Full bleed, square: the app a card is shared into draws its own frame,
  // and rounded corners would show as notches on whatever is behind them.
  canvas.drawRect(const Rect.fromLTWH(0, 0, idCardWidth, idCardHeight), Paint()..color = Ds.panel);

  // Portrait.
  const box = Rect.fromLTWH(_pad, _pad, _portraitW, _portraitH);
  final frame = RRect.fromRectAndRadius(box, const Radius.circular(24));
  canvas.save();
  canvas.clipRRect(frame);
  canvas.drawRect(box, Paint()..color = Ds.raise);
  if (image != null) {
    _cover(canvas, image, box);
  } else {
    final initial = _painter(_initial(face.name), _prose(200, FontWeight.w600, Ds.low))..layout();
    initial.paint(canvas, box.center - Offset(initial.width / 2, initial.height / 2 - 8));
    initial.dispose();
  }
  canvas.restore();
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Ds.edge,
  );

  // Name and tagline, one block centred beside the portrait.
  const tx = _pad + _portraitW + _gap;
  const tw = idCardWidth - tx - _pad;

  var nameSize = 104.0;
  var name = _painter(face.name, _prose(nameSize, FontWeight.w600, Ds.hi, height: 1.15))..layout();
  while (name.width > tw && nameSize > 60) {
    name.dispose();
    nameSize -= 4;
    name = _painter(face.name, _prose(nameSize, FontWeight.w600, Ds.hi, height: 1.15))..layout();
  }
  // Still too long at the floor: cut with an ellipsis.
  name.dispose();
  name = _painter(face.name, _prose(nameSize, FontWeight.w600, Ds.hi, height: 1.15), maxLines: 1)
    ..layout(maxWidth: tw);

  // The tagline: the joke, in the book's own face, sized to what room is left.
  const gap = 48.0;
  final room = _portraitH - name.height - gap;
  TextPainter? line;
  if (face.tagline.isNotEmpty) {
    for (var size = 52.0; size >= 32; size -= 2) {
      line?.dispose();
      line = _painter('“${face.tagline}”', _prose(size, FontWeight.w400, Ds.hi, italic: true, height: 1.3))
        ..layout(maxWidth: tw - 40);
      if (line.height <= room) break;
    }
  }
  final block = name.height + (line != null ? gap + line.height : 0);
  var y = _pad + (_portraitH - block) / 2;

  name.paint(canvas, Offset(tx, y));
  y += name.height + gap;

  if (line != null) {
    canvas.drawRect(Rect.fromLTWH(tx, y, 6, line.height), Paint()..color = Ds.accent);
    line.paint(canvas, Offset(tx + 40, y));
  }

  name.dispose();
  line?.dispose();

  final picture = recorder.endRecording();
  final drawn = await picture.toImage(idCardWidth.toInt(), idCardHeight.toInt());
  final data = await drawn.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  drawn.dispose();
  image?.dispose();
  if (data == null) throw StateError('encode_failed');
  return data.buffer.asUint8List();
}

Future<ui.Image?> _decode(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (e) {
    // A portrait that will not decode draws as the initial, like none at all.
    debugPrint('[idCard] portrait decode failed, drawing the initial: $e');
    return null;
  }
}

/// Fill the box, cropping the long side — `BoxFit.cover`, biased up so a
/// face in a tall picture keeps its head.
void _cover(Canvas canvas, ui.Image img, Rect box) {
  final scale = math.max(box.width / img.width, box.height / img.height);
  final sw = box.width / scale;
  final sh = box.height / scale;
  final sx = (img.width - sw) / 2;
  final sy = (img.height - sh) * 0.3;
  canvas.drawImageRect(img, Rect.fromLTWH(sx, sy, sw, sh), box, Paint()..filterQuality = FilterQuality.high);
}

TextStyle _prose(double size, FontWeight weight, Color color, {bool italic = false, double? height}) => TextStyle(
      fontFamily: DsFonts.prose,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
      height: height,
    );

TextPainter _painter(String text, TextStyle style, {int? maxLines}) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '…' : null,
    );

String _initial(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
}
