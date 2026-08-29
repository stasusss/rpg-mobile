import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/progress_provider.dart';
import '../theme.dart';
import 'common.dart';

/// Compact strip: level, currencies and current location. XP lives in the dock.
///
/// Type scale is derived from the available height so the bar stays legible on
/// short screens without breaking the fixed flex layout.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(playerProvider.select((p) => p.level));
    final gold = ref.watch(playerProvider.select((p) => p.gold));
    final gems = ref.watch(playerProvider.select((p) => p.gems));
    final location = ref.watch(currentLocationProvider);
    final l10n = ref.watch(l10nProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final font = (h * 0.30).clamp(9.0, 13.0);

        return MediaQuery.withClampedTextScaling(
          // The strip is a fixed 5% of the screen; scaling would break it.
          maxScaleFactor: 1,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: h * 0.14),
              child: Row(
                children: [
                  _LevelBadge(
                    fontSize: font,
                    label: l10n.t('ui.level', {'n': '$level'}),
                  ),
                  const Spacer(),
                  ResourceChip(
                    icon: Icons.monetization_on,
                    value: formatCount(gold),
                    color: AppColors.gold,
                    fontSize: font,
                  ),
                  SizedBox(width: h * 0.16),
                  ResourceChip(
                    icon: Icons.diamond,
                    value: formatCount(gems),
                    color: AppColors.gem,
                    fontSize: font,
                  ),
                  SizedBox(width: h * 0.20),
                  Flexible(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          location.icon,
                          size: font + 2.5,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            l10n.locationName(location.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: font,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.fontSize, required this.label});

  final double fontSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
