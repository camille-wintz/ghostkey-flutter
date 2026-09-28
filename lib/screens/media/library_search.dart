import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The library tab's keyword search, over the open part of the library.
class LibrarySearch extends StatelessWidget {
  const LibrarySearch({super.key, required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.only(left: 20, right: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 15, color: Ds.faint),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                cursorColor: Ds.accent,
                style: DsStyle.ui(DsText.body, color: Ds.hi),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search pictures',
                  hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : Press(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      semanticLabel: 'Clear the search',
                      builder: (context, pressed) => Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pressed ? Ds.veil : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(DsGeom.radius),
                        ),
                        child: Icon(LucideIcons.x, size: 15, color: Ds.mid),
                      ),
                    ),
            ),
          ],
        ),
      );
}
