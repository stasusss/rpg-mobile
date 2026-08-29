import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../providers/combat_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../theme.dart';
import 'skill_bar.dart';

/// Potion + three skill slots. [embedded] drops the extra farm-rate chrome.
class QuickActionBar extends ConsumerWidget {
  const QuickActionBar({super.key, this.embedded = false});

  final bool embedded;

  static const double height = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final potions = ref.watch(potionCountProvider);
    final l10n = ref.watch(l10nProvider);

    final row = SizedBox(
      height: height,
      child: Row(
        children: [
          _PotionButton(
            count: potions,
            tooltip: potions > 0
                ? l10n.t('ui.potionQuick')
                : l10n.t('ui.noPotions'),
            onTap: potions <= 0
                ? null
                : () {
                    final uid = ref
                        .read(inventoryProvider.notifier)
                        .findPotionUid();
                    if (uid == null) return;
                    AudioManager.instance.play(SfxKind.click);
                    ref.read(combatProvider.notifier).usePotion(uid);
                  },
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Align(
              alignment: Alignment.center,
              child: ActiveSkillBar(compact: true),
            ),
          ),
        ],
      ),
    );

    if (embedded) return row;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: row,
      ),
    );
  }
}

class _PotionButton extends StatelessWidget {
  const _PotionButton({
    required this.count,
    required this.tooltip,
    required this.onTap,
  });

  final int count;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ready = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.local_drink,
                  size: 22,
                  color: ready ? AppColors.hp : AppColors.textFaint,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ready ? AppColors.text : AppColors.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
