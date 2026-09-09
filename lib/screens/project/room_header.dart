import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/providers.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'project_root.dart';

/// Every room's chrome: which room you are in, and the book you are in it for
/// — where the book's name IS the way back to the project home.
///
/// One widget rather than one header per room. The rooms had each grown their
/// own answer to "how do I get out" (a labelled chevron here, a bare one
/// there, a link at the foot of a drawer somewhere else), which reads as four
/// apps rather than four rooms of one. The name and the mark are a single
/// press target for the same reason the chapter drawer's head is: an arrow
/// beside a label is a 44px target next to 200px of text that looks just as
/// pressable.
class RoomHeader extends ConsumerWidget {
  const RoomHeader({super.key, required this.room, this.trailing});

  /// The room's own name, as the eyebrow over the book's.
  final String room;

  /// The one action this room's chrome carries, if it carries any.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final title = ref.watch(projectProvider(projectId)).value?.project.displayTitle ?? 'Project';

    return Container(
      height: 52,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Press(
                onPressed: () => Navigator.of(context).pop(),
                semanticLabel: 'Back to $title',
                builder: (context, pressed) => Container(
                  height: DsGeom.row,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: pressed ? Ds.veil : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.chevronLeft, size: 17, color: Ds.mid),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(room, color: Ds.accent300),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsStyle.ui(DsText.ui, color: Ds.soft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// The overflow a room's header carries when it has one.
class RoomHeaderAction extends StatelessWidget {
  const RoomHeaderAction({super.key, required this.icon, required this.onPressed, required this.semanticLabel});

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        builder: (context, pressed) => Container(
          width: DsGeom.row,
          height: DsGeom.row,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(icon, size: 17, color: Ds.mid),
        ),
      );
}
