import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/crafting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/progress_provider.dart';
import '../hubs/adventure_hub.dart';
import '../hubs/craft_hub.dart';
import '../hubs/growth_hub.dart';
import '../hubs/hero_hub.dart';
import '../theme.dart';
import 'common.dart';
import 'hub_sheet.dart';
import 'quick_bar.dart';

/// Essential combat strip plus four icon-only hub triggers.
class BottomDock extends ConsumerWidget {
  const BottomDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(playerProvider.select((p) => p.xp));
    final xpForNext = ref.watch(playerProvider.select((p) => p.xpForNext));
    final skillPoints = ref.watch(playerProvider.select((p) => p.skillPoints));
    final unseen = ref.watch(inventoryProvider.select((i) => i.unseenUids.length));
    final craftable = ref.watch(
      recipeStatusesProvider.select(
        (list) => list.where((s) => s.canCraft).length,
      ),
    );
    final newLocations = ref.watch(
      locationUnlocksProvider.select(
        (map) => map.values.where((reason) => reason == null).length,
      ),
    );
    final visited = ref.watch(
      progressProvider.select((p) => p.killsByLocation.length),
    );
    final l10n = ref.watch(l10nProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatBar(
                fraction: xpForNext == 0 ? 0 : xp / xpForNext,
                color: AppColors.xp,
                height: 8,
                label: '${formatCount(xp)} / ${formatCount(xpForNext)}',
              ),
              const SizedBox(height: 6),
              const QuickActionBar(embedded: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  _HubIcon(
                    id: 'hub-hero',
                    icon: Icons.person,
                    tooltip: l10n.t('hub.hero'),
                    count: unseen,
                    onTap: () {
                      ref.read(inventoryProvider.notifier).markBagSeen();
                      openHubSheet(context: context, child: const HeroHub());
                    },
                  ),
                  _HubIcon(
                    id: 'hub-adventure',
                    icon: Icons.map,
                    tooltip: l10n.t('hub.adventure'),
                    badge: newLocations > visited,
                    onTap: () => openHubSheet(
                      context: context,
                      child: const AdventureHub(),
                    ),
                  ),
                  _HubIcon(
                    id: 'hub-craft',
                    icon: Icons.hardware,
                    tooltip: l10n.t('hub.craft'),
                    count: craftable,
                    badgeColor: AppColors.success,
                    onTap: () => openHubSheet(
                      context: context,
                      child: const CraftHub(),
                    ),
                  ),
                  _HubIcon(
                    id: 'hub-skills',
                    icon: Icons.account_tree,
                    tooltip: l10n.t('hub.growth'),
                    count: skillPoints,
                    onTap: () => openHubSheet(
                      context: context,
                      child: const GrowthHub(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubIcon extends StatelessWidget {
  const _HubIcon({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.count = 0,
    this.badge = false,
    this.badgeColor = AppColors.gold,
  });

  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int count;
  final bool badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key(id),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 26, color: AppColors.textMuted),
                  if (count > 0 || badge)
                    Positioned(
                      right: 18,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 14),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count > 0 ? '$count' : '!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
