import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enemies_data.dart';
import '../../data/locations_data.dart';
import '../../providers/locale_provider.dart';
import '../../providers/progress_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Current zone dossier: description, spawns, and local drops.
class LocationDetailView extends ConsumerWidget {
  const LocationDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final progress = ref.watch(progressProvider);
    final l10n = ref.watch(l10nProvider);
    final drops = materialsIn(location);
    final kills = progress.killsIn(location.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        Panel(
          borderColor: AppColors.gold.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(location.icon, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.locationName(location.id),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    l10n.t('ui.level', {'n': '${location.recommendedLevel}'}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.locationRegion(location.id),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.locationDesc(location.id),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('ui.kills', {'n': formatCount(kills)}),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(l10n.t('ui.enemies'), icon: Icons.dangerous),
        for (final spawn in location.spawns)
          if (enemyCatalog[spawn.enemyId] case final enemy?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.hasSeen(enemy.id)
                                ? l10n.enemyName(enemy.id)
                                : '???',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l10n.t('ui.level', {'n': '${enemy.level}'}),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l10n.t('ui.kills', {
                        'n': formatCount(progress.killsOf(enemy.id)),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (drops.isNotEmpty) ...[
          const SizedBox(height: 6),
          SectionTitle(l10n.t('ui.resourceDrops'), icon: Icons.category),
          Panel(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in drops) ItemTile(item: item),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
