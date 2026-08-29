import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/locations_data.dart';
import '../models/prestige.dart';
import '../models/stats.dart';
import 'achievements_provider.dart';
import 'combat_provider.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import 'progress_provider.dart';
import 'save_provider.dart';
import 'skills_provider.dart';

/// Ash Souls wallet and the meta-perk tree. Survives every soft reset.
class PrestigeNotifier extends Notifier<PrestigeState> {
  @override
  PrestigeState build() {
    final saved = savedSection(ref, 'prestige');
    return saved == null
        ? const PrestigeState()
        : PrestigeState.fromJson(saved);
  }

  bool has(MetaPerk perk) => state.has(perk);

  void awardSouls(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(ashSouls: state.ashSouls + amount);
  }

  /// Pays out chronicle bonuses that unlocked since the last collect.
  void collectAchievementSouls() {
    awardSouls(ref.read(achievementsProvider.notifier).takePendingSouls());
  }

  bool buyPerk(MetaPerk perk) {
    if (state.owned.contains(perk)) return false;
    if (state.ashSouls < perk.cost) return false;
    state = state.copyWith(
      ashSouls: state.ashSouls - perk.cost,
      owned: {...state.owned, perk},
    );
    return true;
  }

  PrestigeYield estimatedYield() {
    final player = ref.read(playerProvider);
    final progress = ref.read(progressProvider);
    return calculatePrestigeYield(
      highestLocationIndex: highestLocationIndexReached(progress),
      totalKills: player.totalKills,
      itemsCrafted: player.itemsCrafted,
    );
  }

  /// Soft-resets the current life, keeps meta progress, awards Ash Souls.
  ///
  /// Returns `false` when the altar has nothing to harvest.
  Future<bool> executeAscension() async {
    final yield_ = estimatedYield();
    if (!yield_.canAscend) return false;

    awardSouls(yield_.total);
    ref.read(achievementsProvider.notifier).recordPrestige();
    collectAchievementSouls();

    final heritage = state.has(MetaPerk.emberHeritage);
    ref
        .read(playerProvider.notifier)
        .resetForAscension(bonusGold: heritage ? emberHeritageGold : 0);
    ref.read(progressProvider.notifier).resetForAscension();
    ref
        .read(inventoryProvider.notifier)
        .resetForNewRun(extraMats: heritage ? emberHeritageMats : const {});
    ref.read(skillsProvider.notifier).resetRanks();
    ref.invalidate(combatProvider);
    return true;
  }
}

final prestigeProvider = NotifierProvider<PrestigeNotifier, PrestigeState>(
  PrestigeNotifier.new,
);

/// Permanent combat modifiers from owned meta-perks.
final metaPerkBundleProvider = Provider<StatBundle>((ref) {
  final owned = ref.watch(prestigeProvider.select((p) => p.owned));
  var bundle = StatBundle.empty;
  if (owned.contains(MetaPerk.ashenSwiftness)) {
    bundle = bundle + const StatBundle(pct: {StatKey.attackSpeed: 0.10});
  }
  if (owned.contains(MetaPerk.fortunePilgrim)) {
    bundle = bundle + const StatBundle(pct: {StatKey.lootFind: 0.15});
  }
  if (owned.contains(MetaPerk.soulResonance)) {
    bundle = bundle + const StatBundle(pct: {StatKey.xpGain: 0.25});
  }
  return bundle;
});

/// Farthest map index the current life has stood in or stained with blood.
int highestLocationIndexReached(ProgressState progress) {
  var best = 0;
  for (var i = 0; i < allLocations.length; i++) {
    final loc = allLocations[i];
    if (progress.currentLocationId == loc.id || progress.killsIn(loc.id) > 0) {
      best = i;
    }
  }
  return best;
}
