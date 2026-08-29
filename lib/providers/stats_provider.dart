import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/items_data.dart';
import '../models/item.dart';
import '../models/stats.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import 'player_stats_provider.dart';
import 'prestige_provider.dart';
import 'skills_provider.dart';
import 'time_controller.dart';

/// Every modifier currently affecting the player: gear, sets and skills.
final totalBundleProvider = Provider<StatBundle>(
  (ref) =>
      ref.watch(gearBundleProvider) +
      ref.watch(setBonusBundleProvider) +
      ref.watch(skillBundleProvider) +
      ref.watch(metaPerkBundleProvider),
);

/// Gear / mastery sheet without shop boosters. Time-skip reads this so it
/// cannot depend on [timeControllerProvider] while that notifier is running.
final baseCombatStatsProvider = Provider<CombatStats>((ref) {
  final level = ref.watch(playerProvider.select((p) => p.level));
  return resolveStats(
    level: level,
    allocated: ref.watch(masteryAllocationProvider),
    bundle: ref.watch(totalBundleProvider),
  );
});

/// The resolved character sheet the combat loop reads every tick.
final combatStatsProvider = Provider<CombatStats>((ref) {
  final base = ref.watch(baseCombatStatsProvider);
  final xpOn = ref.watch(
    timeControllerProvider.select((t) => t.xpElixirActive),
  );
  final lootOn = ref.watch(
    timeControllerProvider.select((t) => t.doubleLootActive),
  );
  final berserk = ref.watch(
    timeControllerProvider.select((t) => t.berserkActive),
  );
  final ward = ref.watch(timeControllerProvider.select((t) => t.wardActive));
  return base
      .scaledGains(
        xp: xpOn ? xpElixirMultiplier : 1,
        loot: lootOn ? 2 : 1,
      )
      .withAlchemy(berserk: berserk, ward: ward);
});

/// Sheet recomputed as if [candidate] were worn in its slot, so tooltips can
/// show the true delta rather than a heuristic score.
///
/// Takes a [WidgetRef] because previews are only ever needed by the UI.
CombatStats previewStatsWith(WidgetRef ref, ItemDef candidate) {
  final player = ref.read(playerProvider);
  final equipped = ref.read(inventoryProvider).equipped;
  var bundle = ref.read(skillBundleProvider) + ref.read(metaPerkBundleProvider);
  for (final entry in equipped.entries) {
    if (entry.key == candidate.slot) continue;
    final worn = entry.value;
    if (worn == null) continue;
    final def = tryItemById(worn.itemId);
    if (def != null) bundle = bundle + def.effectiveBonuses;
  }
  bundle = bundle + candidate.effectiveBonuses;
  bundle = bundle + setBundleFor(previewSetProgress(equipped, candidate));
  return resolveStats(
    level: player.level,
    allocated: ref.read(masteryAllocationProvider),
    bundle: bundle,
  );
}

/// Sheet with the item in [slot] removed, for unequip previews.
CombatStats previewStatsWithout(WidgetRef ref, EquipSlot slot) {
  final player = ref.read(playerProvider);
  final equipped = ref.read(inventoryProvider).equipped;
  var bundle = ref.read(skillBundleProvider) + ref.read(metaPerkBundleProvider);
  final remaining = <EquipSlot, InventoryEntry?>{
    for (final e in equipped.entries)
      if (e.key != slot) e.key: e.value,
  };
  for (final entry in remaining.values) {
    if (entry == null) continue;
    final def = tryItemById(entry.itemId);
    if (def != null) bundle = bundle + def.effectiveBonuses;
  }
  bundle =
      bundle +
      setBundleFor(
        setProgressFromIds([
          for (final entry in remaining.values)
            if (entry != null) entry.itemId,
        ]),
      );
  return resolveStats(
    level: player.level,
    allocated: ref.read(masteryAllocationProvider),
    bundle: bundle,
  );
}
