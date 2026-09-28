import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../media/photo.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';

/// An empty library: what goes in it, and the three ways in.
class LibraryEmpty extends StatelessWidget {
  const LibraryEmpty({super.key, required this.onPhoto, required this.onDraw});
  final ValueChanged<PhotoSource> onPhoto;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.images, size: 34, color: Ds.faint),
              const SizedBox(height: 14),
              Text('No pictures yet.', style: DsStyle.ui(DsText.body, color: Ds.mid)),
              const SizedBox(height: 6),
              Text(
                'Take a photo, add one from your photos, or draw one.',
                textAlign: TextAlign.center,
                style: DsStyle.ui(DsText.ui, color: Ds.low),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  GkButton(
                    label: 'Take a photo',
                    variant: ButtonVariant.outline,
                    leading: Icon(LucideIcons.camera, size: 15, color: Ds.soft),
                    onPressed: () => onPhoto(PhotoSource.camera),
                  ),
                  GkButton(
                    label: 'From your photos',
                    variant: ButtonVariant.outline,
                    leading: Icon(LucideIcons.image, size: 15, color: Ds.soft),
                    onPressed: () => onPhoto(PhotoSource.photos),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Press(
                onPressed: onDraw,
                semanticLabel: 'Draw one',
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.7 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Draw one', style: DsStyle.ui(DsText.ui, color: Ds.accent, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
