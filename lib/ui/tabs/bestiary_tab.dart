import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enemies_data.dart';
import '../../data/items_data.dart';
import '../../data/locations_data.dart';
import '../../models/enemy.dart';
import '../../providers/locale_provider.dart';
import '../../providers/progress_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/item_sheet.dart';

/// Kill-gated monster compendium. Unseen entries stay redacted so discovery
/// still means something, but always name the place you can find them.
class BestiaryTab extends ConsumerWidget {
  const BestiaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final completion = ref.watch(bestiaryProgressProvider);
    final enemies = allEnemiesByLevel;
    final l10n = ref.watch(l10nProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.menu_book, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('ui.discovered', {
                        'seen': '${completion.seen}',
                        'total': '${completion.total}',
                      }),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatBar(
                      fraction: completion.total == 0
                          ? 0
                          : completion.seen / completion.total,
                      color: AppColors.info,
                      height: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final enemy in enemies)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BestiaryEntry(
              enemy: enemy,
              kills: progress.killsOf(enemy.id),
              discovered: progress.discoveredItems,
            ),
          ),
      ],
    );
  }
}

class _BestiaryEntry extends ConsumerWidget {
  const _BestiaryEntry({
    required this.enemy,
    required this.kills,
    required this.discovered,
  });

  final EnemyDef enemy;
  final int kills;
  final Set<String> discovered;

  bool get seen => kills > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final home = allLocations.firstWhere(
      (l) => l.enemyIds.contains(enemy.id),
      orElse: () => allLocations.first,
    );

    return Panel(
      padding: const EdgeInsets.all(10),
      borderColor: enemy.isBoss && seen
          ? AppColors.gold.withValues(alpha: 0.5)
          : AppColors.outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Portrait(enemy: enemy, revealed: seen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (enemy.isBoss)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.star,
                              size: 12,
                              color: AppColors.gold,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            seen ? l10n.enemyName(enemy.id) : '???',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: seen
                                  ? (enemy.isBoss
                                        ? AppColors.gold
                                        : AppColors.text)
                                  : AppColors.textFaint,
                            ),
                          ),
                        ),
                        Text(
                          l10n.t('ui.level', {'n': '${enemy.level}'}),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.locationName(home.id)} · '
                      '${seen ? l10n.t('ui.kills', {'n': '$kills'}) : l10n.t('ui.undiscovered')}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (seen) ...[
            if (enemy.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.enemyDesc(enemy.id),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(
                  icon: Icons.favorite,
                  label: formatCount(enemy.maxHp),
                  color: AppColors.hp,
                ),
                _MiniStat(
                  icon: Icons.flash_on,
                  label: formatCount(enemy.damage),
                  color: AppColors.gold,
                ),
                _MiniStat(
                  icon: Icons.speed,
                  label: '${formatStat(enemy.attackSpeed)}/s',
                  color: AppColors.info,
                ),
                _MiniStat(
                  icon: Icons.shield,
                  label: formatCount(enemy.armor),
                  color: AppColors.textMuted,
                ),
                _MiniStat(
                  icon: Icons.trending_up,
                  label: l10n.t('ui.xpAmount', {'n': '${enemy.xp}'}),
                  color: AppColors.xp,
                ),
              ],
            ),
            if (enemy.loot.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final drop in enemy.loot)
                    _LootChip(
                      drop: drop,
                      revealed: discovered.contains(drop.itemId),
                    ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Text(
              l10n.t('ui.bestiaryHint', {
                'location': l10n.locationName(home.id),
              }),
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Colour-block silhouette derived from the enemy's render palette.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.enemy, required this.revealed});

  final EnemyDef enemy;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final visual = enemy.visual;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: revealed
              ? [visual.body, visual.accent]
              : [AppColors.surfaceAlt, AppColors.surface],
        ),
      ),
      child: Icon(
        revealed ? _iconFor(visual.plan) : Icons.question_mark,
        size: 19,
        color: revealed
            ? Colors.black.withValues(alpha: 0.55)
            : AppColors.textFaint,
      ),
    );
  }

  static IconData _iconFor(BodyPlan plan) => switch (plan) {
    BodyPlan.humanoid => Icons.person,
    BodyPlan.hulk => Icons.accessibility_new,
    BodyPlan.quadruped => Icons.pets,
    BodyPlan.blob => Icons.water_drop,
    BodyPlan.flyer => Icons.air,
    BodyPlan.arachnid => Icons.bug_report,
  };
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LootChip extends ConsumerWidget {
  const _LootChip({required this.drop, required this.revealed});

  final LootDrop drop;
  final bool revealed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = tryItemById(drop.itemId);
    if (item == null) return const SizedBox.shrink();
    final l10n = ref.watch(l10nProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: revealed ? () => showItemSheet(context, item) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: revealed
                  ? item.rarity.color.withValues(alpha: 0.5)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                revealed ? item.icon : Icons.help_outline,
                size: 12,
                color: revealed ? item.rarity.color : AppColors.textFaint,
              ),
              const SizedBox(width: 4),
              Text(
                revealed ? l10n.itemName(item.id) : l10n.t('ui.unknownEnemy'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: revealed ? AppColors.text : AppColors.textFaint,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                formatPercent(drop.chance, decimals: 0),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
