import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enemies_data.dart';
import '../../l10n/l10n.dart';
import '../../models/item.dart';
import '../../models/stats.dart';
import '../../providers/combat_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/stats_provider.dart';
import '../theme.dart';
import 'common.dart';

/// Opens the item inspector. [uid] identifies the owned stack, [equippedSlot]
/// is set when the item is currently worn.
void showItemSheet(
  BuildContext context,
  ItemDef item, {
  String? uid,
  EquipSlot? equippedSlot,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ItemSheet(item: item, uid: uid, equippedSlot: equippedSlot),
  );
}

class _ItemSheet extends ConsumerWidget {
  const _ItemSheet({required this.item, this.uid, this.equippedSlot});

  final ItemDef item;
  final String? uid;
  final EquipSlot? equippedSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(playerProvider.select((p) => p.level));
    final canUseLevel = level >= item.levelReq;
    final l10n = ref.watch(l10nProvider);
    final desc = l10n.itemDesc(item.id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(l10n),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ],
              if (item.setId != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.itemSet(item.setId!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: item.setId!.color,
                  ),
                ),
              ],
              if (!item.effectiveBonuses.isEmpty) ...[
                const SizedBox(height: 12),
                SectionTitle(l10n.t('ui.bonuses')),
                ...l10n
                    .describeBundle(item.effectiveBonuses)
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
              ],
              if (item.isEquipment) _comparison(ref, l10n),
              if (item.kind == ItemKind.material)
                _dropSources(context, ref, l10n),
              const SizedBox(height: 14),
              _actions(context, ref, canUseLevel, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(L10n l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ItemTile(item: item, size: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.itemName(item.id),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  l10n.rarity(item.rarity),
                  if (item.slot != null) l10n.slot(item.slot!),
                  if (item.kind == ItemKind.material)
                    l10n.kind(ItemKind.material),
                  if (item.kind == ItemKind.consumable)
                    l10n.kind(ItemKind.consumable),
                ].join(' · '),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: item.rarity.color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (item.levelReq > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        l10n.t('ui.requiresLv', {'n': '${item.levelReq}'}),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                  ResourceChip(
                    icon: Icons.monetization_on,
                    value: '${item.sellValue}',
                    color: AppColors.gold,
                    fontSize: 11,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Side-by-side sheet delta for the slot this item would occupy.
  Widget _comparison(WidgetRef ref, L10n l10n) {
    final current = ref.watch(combatStatsProvider);
    final preview = equippedSlot != null
        ? previewStatsWithout(ref, equippedSlot!)
        : previewStatsWith(ref, item);

    final rows = <(String, double, double, bool)>[
      (l10n.t('ui.dps'), current.dps, preview.dps, false),
      (l10n.stat(StatKey.maxHp), current.maxHp, preview.maxHp, false),
      (l10n.stat(StatKey.armor), current.armor, preview.armor, false),
      (
        l10n.stat(StatKey.attackSpeed),
        current.attackSpeed,
        preview.attackSpeed,
        false,
      ),
      (l10n.stat(StatKey.crit), current.crit, preview.crit, true),
      (l10n.stat(StatKey.dodge), current.dodge, preview.dodge, true),
      (
        l10n.stat(StatKey.fireDamage),
        current.fireDamage,
        preview.fireDamage,
        false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SectionTitle(
          equippedSlot != null
              ? l10n.t('ui.ifUnequipped')
              : l10n.t('ui.ifEquipped'),
        ),
        ...rows.where((r) => (r.$3 - r.$2).abs() > 0.0005).map((r) {
          final delta = r.$3 - r.$2;
          return StatLine(
            label: r.$1,
            value: r.$4 ? formatPercent(r.$3) : formatStat(r.$3),
            delta: r.$4 ? delta * 100 : delta,
          );
        }),
        if (rows.every((r) => (r.$3 - r.$2).abs() <= 0.0005))
          Text(
            l10n.t('ui.noStatChange'),
            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
      ],
    );
  }

  /// Where this material comes from, so farming has a clear destination.
  Widget _dropSources(BuildContext context, WidgetRef ref, L10n l10n) {
    final sources = enemiesDropping(item.id);
    if (sources.isEmpty) return const SizedBox.shrink();
    final target = ref.watch(lootTargetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SectionTitle(l10n.t('ui.dropsFrom')),
        ...sources.take(6).map((enemy) {
          final drop = enemy.loot.firstWhere((d) => d.itemId == item.id);
          return StatLine(
            label:
                '${l10n.enemyName(enemy.id)} (${l10n.t('ui.level', {'n': '${enemy.level}'})})',
            value: formatPercent(drop.chance, decimals: 0),
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final notifier = ref.read(lootTargetProvider.notifier);
              if (target == item.id) {
                notifier.clear();
              } else {
                notifier.setTarget(item.id);
              }
              Navigator.of(context).pop();
            },
            icon: Icon(
              target == item.id ? Icons.close : Icons.my_location,
              size: 15,
            ),
            label: Text(
              target == item.id ? l10n.t('ui.clearFarm') : l10n.t('ui.setFarm'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    bool canUseLevel,
    L10n l10n,
  ) {
    final buttons = <Widget>[];
    final inventory = ref.read(inventoryProvider.notifier);

    if (equippedSlot != null) {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              inventory.unequip(equippedSlot!);
              Navigator.of(context).pop();
            },
            child: Text(l10n.t('ui.unequip')),
          ),
        ),
      );
    } else if (uid != null && item.isEquipment) {
      buttons.add(
        Expanded(
          child: FilledButton(
            onPressed: canUseLevel
                ? () {
                    inventory.equip(uid!);
                    Navigator.of(context).pop();
                  }
                : null,
            child: Text(
              canUseLevel
                  ? l10n.t('ui.equip')
                  : l10n.t('ui.levelN', {'n': '${item.levelReq}'}),
            ),
          ),
        ),
      );
    } else if (uid != null && item.kind == ItemKind.consumable) {
      buttons.add(
        Expanded(
          child: FilledButton(
            onPressed: () {
              ref.read(combatProvider.notifier).usePotion(uid!);
              Navigator.of(context).pop();
            },
            child: Text(l10n.t('ui.use')),
          ),
        ),
      );
    }

    if (uid != null && equippedSlot == null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              final gold = inventory.sell(uid!);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.t('ui.soldFor', {'gold': '$gold'})),
                ),
              );
            },
            child: Text(l10n.t('ui.sell')),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(children: buttons);
  }
}

/// Formats a [StatBundle] into a single comma separated line for dense lists.
String describeBundleInline(StatBundle bundle) =>
    bundle.describe().join('  ·  ');
