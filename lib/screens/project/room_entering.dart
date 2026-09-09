import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../rooms/room_tile.dart';
import '../../rooms/rooms.dart';

/// The face a room wears while it is being built: the mark the author just
/// pressed, at the size the row drew it, and the room's name under it. Not a
/// skeleton of the room's own furniture — a grey stand-in for someone's
/// manuscript is a worse lie than an honest wait.
class RoomEntering extends StatefulWidget {
  const RoomEntering({super.key, required this.room});
  final Room room;

  @override
  State<RoomEntering> createState() => _RoomEnteringState();
}

class _RoomEnteringState extends State<RoomEntering> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Opening ${widget.room.title}',
        child: ColoredBox(
          color: Ds.void_,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.55, end: 1.0).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
                child: RoomTile(tile: widget.room.tile, mark: widget.room.mark, size: 60, iconSize: 29),
              ),
              const SizedBox(height: 18),
              Text(widget.room.title.toUpperCase(), style: DsStyle.eyebrow(weight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

/// Has this route finished arriving? A pushed screen that mounts a whole
/// room in the frame the push starts spends that cost on exactly the frames
/// the entry animation needs. So a room draws [RoomEntering] first and asks
/// this widget when the animation is over.
class Entered extends StatefulWidget {
  const Entered({super.key, required this.room, required this.builder});
  final Room room;
  final WidgetBuilder builder;

  @override
  State<Entered> createState() => _EnteredState();
}

class _EnteredState extends State<Entered> {
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _entered = true;
      return;
    }
    void done(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted && !_entered) {
        animation.removeStatusListener(done);
        setState(() => _entered = true);
      }
    }

    animation.addStatusListener(done);
    // If no completion arrives, mount anyway — a screen that never settles is
    // a screen that never draws.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_entered) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) => _entered ? widget.builder(context) : RoomEntering(room: widget.room);
}
