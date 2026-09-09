import 'package:flutter/widgets.dart';

import '../../ui/notice_modal.dart';

/// What the room says when a write is refused — the RN `Alert.alert`, in the
/// house's notice shell. One dismiss, nothing to buy.
Future<void> showRoomAlert(BuildContext context, {required String title, required String message}) =>
    showNoticeModal(
      context,
      eyebrow: 'Apparition',
      title: title,
      action: 'OK',
      children: [NoticeText(message)],
    );
