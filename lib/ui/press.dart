import 'package:flutter/widgets.dart';

/// The house press: the RN `Pressable`'s `({ pressed })` style callback as a
/// widget. A phone has no pointer to hover with, so a press is what the web
/// system's hover becomes — it moves the same properties, in the same 140ms.
///
/// No ink ripple: the house is matte, and a Material splash on a hairline
/// surface reads as a different app.
class Press extends StatefulWidget {
  const Press({
    super.key,
    required this.onPressed,
    required this.builder,
    this.onLongPress,
    this.enabled = true,
    this.hitSlop = 0,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget Function(BuildContext context, bool pressed) builder;
  final bool enabled;
  final double hitSlop;
  final String? semanticLabel;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final inert = !widget.enabled || widget.onPressed == null;
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: inert ? null : (_) => _set(true),
      onTapUp: inert ? null : (_) => _set(false),
      onTapCancel: inert ? null : () => _set(false),
      onTap: inert ? null : widget.onPressed,
      onLongPress: inert ? null : widget.onLongPress,
      child: Padding(
        padding: EdgeInsets.all(widget.hitSlop),
        child: widget.builder(context, _pressed && !inert),
      ),
    );
    if (widget.hitSlop > 0) {
      child = Transform.translate(offset: Offset.zero, child: child);
    }
    return Semantics(
      button: true,
      enabled: !inert,
      label: widget.semanticLabel,
      child: child,
    );
  }
}
