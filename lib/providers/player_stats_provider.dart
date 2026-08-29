import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/items_data.dart';
import '../data/sets_data.dart';
import '../models/item.dart';
import '../models/item_set.dart';
import '../models/mastery.dart';
import '../models/stats.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';

/// Derived mastery from combat action counters.
///
/// Attributes are no longer spent by hand: hits raise weapon mastery
/// (attack power), damage taken raises armor mastery (HP / armor), and
/// kills raise character rank (agility + intelligence).
final playerStatsProvider = Provider<ActionMastery>((ref) {
  final player = ref.watch(playerProvider);
  return ActionMastery(
    hitsDealt: player.hitsDealt,
    damageTaken: player.damageTaken,
    enemiesKilled: player.totalKills,
  );
});

/// Attribute spread produced by the current mastery levels.
final masteryAllocationProvider = Provider<Map<Attribute, int>>((ref) {
  final mastery = ref.watch(
    playerStatsProvider.select(
      (m) => (m.weaponMastery, m.armorMastery, m.characterRank),
    ),
  );
  return {
    Attribute.strength: 5 + mastery.$1,
    Attribute.endurance: 5 + mastery.$2,
    Attribute.agility: 5 + mastery.$3,
    Attribute.intelligence: 5 + mastery.$3,
  };
});

/// How many set pieces are currently worn, plus the active bonuses.
final setBonusProvider = Provider<List<SetProgress>>((ref) {
  final equipped = ref.watch(inventoryProvider).equipped;
  final wornIds = <String>{
    for (final entry in equipped.values)
      if (entry != null) entry.itemId,
  };
  return [
    for (final def in allItemSets)
      SetProgress(
        def: def,
        equipped: def.pieceIds.where(wornIds.contains).length,
      ),
  ];
});

final setBonusBundleProvider = Provider<StatBundle>((ref) {
  var bundle = StatBundle.empty;
  for (final progress in ref.watch(setBonusProvider)) {
    bundle = bundle + progress.bundle;
  }
  return bundle;
});

final setThornsProvider = Provider<double>((ref) {
  var thorns = 0.0;
  for (final progress in ref.watch(setBonusProvider)) {
    thorns += progress.thorns;
  }
  return thorns.clamp(0.0, 0.6);
});

List<SetProgress> setProgressFromIds(Iterable<String> wornIds) {
  final ids = wornIds.toSet();
  return [
    for (final def in allItemSets)
      SetProgress(def: def, equipped: def.pieceIds.where(ids.contains).length),
  ];
}

/// Set progress as if [candidate] were worn (for item comparison sheets).
List<SetProgress> previewSetProgress(
  Map<EquipSlot, InventoryEntry?> equipped,
  ItemDef candidate,
) {
  return setProgressFromIds([
    for (final e in equipped.entries)
      if (e.value != null && e.key != candidate.slot) e.value!.itemId,
    candidate.id,
  ]);
}

StatBundle setBundleFor(List<SetProgress> progress) {
  var bundle = StatBundle.empty;
  for (final p in progress) {
    bundle = bundle + p.bundle;
  }
  return bundle;
}

/// Effective bonuses from one equipped item id.
StatBundle effectiveGearBonuses(String itemId) {
  final def = tryItemById(itemId);
  if (def == null) return StatBundle.empty;
  return def.effectiveBonuses;
}
