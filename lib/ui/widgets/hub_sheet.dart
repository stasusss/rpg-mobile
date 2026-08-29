import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../theme.dart';

/// Opens a hub at 70% height with a drag handle for swipe-to-dismiss.
Future<void> openHubSheet({
  required BuildContext context,
  required Widget child,
}) {
  AudioManager.instance.play(SfxKind.click);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.70;
      return SizedBox(
        height: height,
        child: Material(color: AppColors.background, child: child),
      );
    },
  );
}
