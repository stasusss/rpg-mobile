import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/items_data.dart';
import '../../data/locations_data.dart';
import '../../models/gear_score.dart';
import '../../models/item.dart';
import '../../models/item_set.dart';
import '../../providers/crafting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_stats_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/item_actions.dart';
import '../widgets/item_sheet.dart';

/// Paper-doll and bag grid for the Hero hub.
class GearInventoryView extends ConsumerWidget {
  const GearInventoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final gear = ref.watch(bagEquipmentProvider);
    final materials = ref.watch(bagMaterialsProvider);
    final l10n = ref.watch(l10nProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        SectionTitle(l10n.t('ui.equipped'), icon: Icons.person_outline),
        Panel(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final slot in EquipSlot.values)
                _EquippedSlot(slot: slot, entry: inventory.equipped[slot]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _EquippedSetsStrip(),
        const SizedBox(height: 14),
        SectionTitle(
          l10n.t('ui.bag', {
            'used': '${inventory.usedSlots}',
            'cap': '${inventory.capacity}',
          }),
          icon: Icons.backpack_outlined,
          trailing: const _SellJunkButton(),
        ),
        if (gear.isEmpty)
          Panel(
            child: EmptyHint(
              message: l10n.t('ui.emptyGear'),
              icon: Icons.inventory_2_outlined,
            ),
          )
        else
          Panel(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final entry in gear) _BagGearTile(entry: entry)],
            ),
          ),
        if (materials.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionTitle(l10n.t('ui.materials'), icon: Icons.category),
          Panel(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in materials)
                  if (tryItemById(entry.itemId) case final item?)
                    ItemTile(
                      item: item,
                      quantity: entry.quantity,
                      onTap: () => showItemContextMenu(
                        context,
                        ref,
                        item,
                        uid: entry.uid,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EquippedSetsStrip extends ConsumerWidget {
  const _EquippedSetsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(setBonusProvider);
    final worn = sets.where((s) => s.equipped > 0).toList();
    final l10n = ref.watch(l10nProvider);
    if (worn.isEmpty) return const SizedBox.shrink();

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          for (final progress in worn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.style, size: 13, color: progress.def.id.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.itemSet(progress.def.id),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: progress.def.id.color,
                      ),
                    ),
                  ),
                  Text(
                    '${progress.equipped}/${progress.max}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: progress.hasFour
                          ? AppColors.gold
                          : progress.hasTwo
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                  ),
                  if (progress.hasTwo || progress.hasFour) ...[
                    const SizedBox(width: 6),
                    Text(
                      progress.hasFour ? '4' : '2',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: progress.hasFour
                            ? AppColors.gold
                            : AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EquippedSlot extends ConsumerWidget {
  const _EquippedSlot({required this.slot, required this.entry});

  final EquipSlot slot;
  final InventoryEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final item = entry == null ? null : tryItemById(entry!.itemId);

    return SizedBox(
      width: 62,
      child: Column(
        children: [
          if (item == null)
            EmptySlotTile(slot: slot, size: 48)
          else
            ItemTile(
              item: item,
              size: 48,
              badge: '',
              onTap: () => showItemContextMenu(
                context,
                ref,
                item,
                uid: entry!.uid,
                equippedSlot: slot,
              ),
            ),
          const SizedBox(height: 3),
          Text(
            item == null ? l10n.slot(slot) : l10n.itemName(item.id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: item == null ? AppColors.textFaint : item.rarity.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BagGearTile extends ConsumerWidget {
  const _BagGearTile({required this.entry});

  final InventoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = tryItemById(entry.itemId);
    if (item == null) return const SizedBox.shrink();

    final equipped = ref.watch(
      inventoryProvider.select((inv) => inv.equipped[item.slot]),
    );
    final level = ref.watch(playerProvider.select((p) => p.level));
    final currentScore = equipped == null
        ? -1.0
        : gearScore(itemById(equipped.itemId));

    return ItemTile(
      item: item,
      quantity: entry.quantity,
      dimmed: level < item.levelReq,
      showUpgradeHint: gearScore(item) > currentScore && level >= item.levelReq,
      onTap: () => showItemContextMenu(context, ref, item, uid: entry.uid),
    );
  }
}

class _SellJunkButton extends ConsumerWidget {
  const _SellJunkButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarity = ref.watch(settingsProvider.select((s) => s.autoSellRarity));
    final l10n = ref.watch(l10nProvider);

    return IconButton(
      tooltip: l10n.t('ui.sellRarity', {'rarity': l10n.rarity(rarity)}),
      onPressed: () {
        final gold = ref.read(inventoryProvider.notifier).sellGearUpTo(rarity);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gold > 0
                  ? l10n.t('ui.soldJunk', {
                      'rarity': l10n.rarity(rarity),
                      'gold': '$gold',
                    })
                  : l10n.t('ui.nothingToSell'),
            ),
          ),
        );
      },
      icon: const Icon(Icons.sell_outlined, size: 20),
    );
  }
}

// ------------------------------------------------------------- materials view

class MaterialsInventoryView extends ConsumerWidget {
  const MaterialsInventoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(bagMaterialsProvider);
    final target = ref.watch(lootTargetProvider);
    final l10n = ref.watch(l10nProvider);

    if (materials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Panel(
          child: EmptyHint(
            message: l10n.t('ui.emptyMatsLong'),
            icon: Icons.science_outlined,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        SectionTitle(l10n.t('ui.materials'), icon: Icons.category),
        Panel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in materials)
                if (tryItemById(entry.itemId) case final item?)
                  ItemTile(
                    item: item,
                    quantity: entry.quantity,
                    showUpgradeHint: target == item.id,
                    onTap: () => showItemContextMenu(
                      context,
                      ref,
                      item,
                      uid: entry.uid,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- craft view

class CraftRecipesView extends ConsumerStatefulWidget {
  const CraftRecipesView({super.key, this.alchemyOnly = false});

  final bool alchemyOnly;

  @override
  ConsumerState<CraftRecipesView> createState() => _CraftRecipesViewState();
}

class _CraftRecipesViewState extends ConsumerState<CraftRecipesView> {
  ItemRarity? _rarity;
  ItemSetId? _set;

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(recipeStatusesProvider);
    final l10n = ref.watch(l10nProvider);
    final filtered = statuses.where((status) {
      final output = tryItemById(status.recipe.outputItemId);
      if (output == null) return false;
      final alchemy = output.kind == ItemKind.consumable;
      if (widget.alchemyOnly != alchemy) return false;
      if (_rarity != null && output.rarity != _rarity) return false;
      if (_set != null && output.setId != _set) return false;
      return true;
    }).toList();
    final ready = filtered.where((s) => s.canCraft).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                l10n.t('ui.recipes', {'n': '$ready'}),
                icon: Icons.hardware,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.t('ui.filter'),
              icon: Icon(
                Icons.filter_list,
                color: _rarity != null || _set != null
                    ? AppColors.gold
                    : AppColors.textMuted,
              ),
              color: AppColors.surfaceHigh,
              onSelected: (value) {
                setState(() {
                  if (value == 'all') {
                    _rarity = null;
                    _set = null;
                    return;
                  }
                  final rarity = ItemRarity.values
                      .where((r) => r.name == value)
                      .firstOrNull;
                  if (rarity != null) {
                    _rarity = rarity;
                    _set = null;
                    return;
                  }
                  final setId = ItemSetId.values
                      .where((s) => s.name == value)
                      .firstOrNull;
                  if (setId != null) {
                    _set = setId;
                    _rarity = null;
                  }
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Text(l10n.t('ui.filterAll')),
                ),
                for (final rarity in ItemRarity.values)
                  PopupMenuItem(
                    value: rarity.name,
                    child: Text(l10n.rarity(rarity)),
                  ),
                if (!widget.alchemyOnly)
                  for (final id in ItemSetId.values)
                    PopupMenuItem(
                      value: id.name,
                      child: Text(l10n.itemSet(id)),
                    ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final status in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecipeCard(status: status),
          ),
      ],
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.status});

  final RecipeStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = status.recipe;
    final output = tryItemById(recipe.outputItemId);
    if (output == null) return const SizedBox.shrink();
    final progress = status.materialProgress;
    final l10n = ref.watch(l10nProvider);

    return Panel(
      padding: const EdgeInsets.all(10),
      borderColor: status.canCraft
          ? AppColors.success.withValues(alpha: 0.45)
          : AppColors.outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ItemTile(
                item: output,
                size: 48,
                badge: recipe.outputQuantity > 1
                    ? 'x${recipe.outputQuantity}'
                    : '',
                onTap: () => showItemSheet(context, output),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.itemName(output.id),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: output.rarity.color,
                      ),
                    ),
                    Text(
                      [
                        l10n.rarity(output.rarity),
                        if (output.slot != null) l10n.slot(output.slot!),
                        if (output.setId != null) l10n.itemSet(output.setId!),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: output.setId?.color ?? AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (recipe.goldCost > 0)
                    ResourceChip(
                      icon: Icons.monetization_on,
                      value: formatCount(recipe.goldCost),
                      color: AppColors.gold,
                      fontSize: 11,
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => _craft(context, ref),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        status.canCraft
                            ? l10n.t('ui.craft')
                            : l10n.t('ui.needMats'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatBar(
            fraction: progress,
            color: status.canCraft ? AppColors.success : AppColors.info,
            height: 7,
            label: status.canCraft
                ? l10n.t('ui.ready')
                : l10n.t('ui.materialsPct', {
                    'n': '${(progress * 100).round()}',
                  }),
          ),
          const SizedBox(height: 8),
          for (final input in recipe.inputs.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _MaterialRequirement(
                itemId: input.key,
                needed: input.value,
                owned: status.owned[input.key] ?? 0,
              ),
            ),
          if (status.block != null)
            Text(
              status.block!.label(recipe, l10n),
              style: const TextStyle(fontSize: 10.5, color: AppColors.hp),
            ),
        ],
      ),
    );
  }

  void _craft(BuildContext context, WidgetRef ref) {
    final result = ref.read(craftingProvider).craft(status.recipe.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? AppColors.success.withValues(alpha: 0.9)
            : AppColors.hp.withValues(alpha: 0.9),
      ),
    );
  }
}

class _MaterialRequirement extends ConsumerWidget {
  const _MaterialRequirement({
    required this.itemId,
    required this.needed,
    required this.owned,
  });

  final String itemId;
  final int needed;
  final int owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = tryItemById(itemId);
    if (item == null) return const SizedBox.shrink();
    final enough = owned >= needed;
    final zones = zonesDroppingItem(itemId);
    final l10n = ref.watch(l10nProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(lootTargetProvider.notifier).setTarget(item.id);
          showItemSheet(context, item);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, size: 13, color: item.rarity.color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${l10n.itemName(item.id)}  $owned/$needed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: enough ? AppColors.success : AppColors.text,
                    ),
                  ),
                ),
                if (zones.isNotEmpty)
                  Text(
                    l10n.locationName(zones.first.id),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textFaint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            StatBar(
              fraction: needed == 0 ? 1 : (owned / needed).clamp(0.0, 1.0),
              color: enough ? AppColors.success : AppColors.gold,
              height: 5,
            ),
          ],
        ),
      ),
    );
  }
}
