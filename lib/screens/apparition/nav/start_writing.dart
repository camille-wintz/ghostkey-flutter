import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../rooms/room_tile.dart';
import '../../../rooms/rooms.dart';
import '../../../ui/press.dart';

/// A book with no chapters: the list gives way to one big door, the desk's
/// "Write the first chapter" (StartBook) — a blank chapter, created and
/// opened. Washed and edged in the accent like the project home's Apparition
/// card, and held while the chapter is being made, so a second tap doesn't
/// make a second one.
class StartWriting extends StatefulWidget {
  const StartWriting({super.key, required this.onStart});
  final Future<void> Function() onStart;

  @override
  State<StartWriting> createState() => _StartWritingState();
}

class _StartWritingState extends State<StartWriting> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onStart();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = roomFor(RoomKey.apparition);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Press(
        onPressed: _start,
        enabled: !_busy,
        semanticLabel: 'Start writing',
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Ds.accentMix(pressed ? 22 : 14), pressed ? Ds.veilHi : Ds.veil],
              stops: const [0, 0.7],
            ),
            border: Border.all(color: Ds.accentMix(pressed ? 70 : 40)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              RoomTile(tile: room.tile, mark: room.mark, size: 76, iconSize: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start writing', style: DsStyle.prose(const DsStep(26, 30), weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'A blank page, ready for you.',
                      style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent))
                  : Icon(LucideIcons.arrowRight, size: 20, color: pressed ? Ds.accent200 : Ds.accent),
            ],
          ),
        ),
      ),
    );
  }
}
