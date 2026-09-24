import 'package:flutter/rendering.dart';

/// The gutter beside a card: a node where the card starts, a line up to the
/// card above when this one hangs under it, and a line down when the next
/// one hangs under this.
class ChainPainter extends CustomPainter {
  const ChainPainter({required this.nodeY, required this.joinedAbove, required this.joinsBelow, required this.color});
  final double nodeY;
  final bool joinedAbove;
  final bool joinsBelow;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    if (joinedAbove) canvas.drawLine(Offset(x, 0), Offset(x, nodeY), line);
    if (joinsBelow) canvas.drawLine(Offset(x, nodeY), Offset(x, size.height), line);
    canvas.drawCircle(Offset(x, nodeY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ChainPainter old) =>
      old.nodeY != nodeY || old.joinedAbove != joinedAbove || old.joinsBelow != joinsBelow || old.color != color;
}
