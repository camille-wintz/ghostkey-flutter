import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../media/photo.dart';
import '../../ui/menu_sheet.dart';

/// The library tab's two ways in that are not drawing: the camera and the
/// phone's photos. Drawing is the other tab.
Future<PhotoSource?> showAddPictureSheet(BuildContext context) => showMenuSheet<PhotoSource>(
      context,
      title: 'Add a picture',
      entries: const [
        MenuEntry(icon: LucideIcons.camera, label: 'Take a photo', value: PhotoSource.camera),
        MenuEntry(icon: LucideIcons.image, label: 'From your photos', value: PhotoSource.photos),
      ],
    );
