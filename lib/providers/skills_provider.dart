import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/skills_data.dart';
import '../l10n/l10n.dart';
import '../models/skill.dart';
import '../models/stats.dart';
import 'player_provider.dart';
import 'save_provider.dart';

/// Why a skill node cannot be learned right now, or null when it can.
enum SkillBlock { maxRank, noPoints, noGold, missingPrereq, levelTooLow }

extension SkillBlockLabel on SkillBlock {
  String label(SkillDef def, L10n l10n, {int gold = 0}) => switch (this) {
    SkillBlock.maxRank => l10n.t('ui.maxed'),
    SkillBlock.noPoints => l10n.t(
      def.skillPointCost == 1 ? 'ui.needSpOne' : 'ui.needSp',
      {'n': '${def.skillPointCost}'},
    ),
    SkillBlock.noGold => l10n.t('ui.needGold', {'n': '$gold'}),
    SkillBlock.missingPrereq => l10n.t('ui.requiresSkills', {
      'names': def.requires.map(l10n.skillName).join(', '),
    }),
    SkillBlock.levelTooLow => l10n.t('ui.requiresLevel', {
      'n': '${def.requiredLevel}',
    }),
  };
}

/// Aggregated perk magnitudes from every learned perk node.
@immutable
class LearnedPerks {
  const LearnedPerks({
    this.doubleLoot = 0,
    this.execute = 0,
    this.thorns = 0,
    this.goldOnHit = 0,
  });

  final double doubleLoot;
  final double execute;
  final double thorns;
  final double goldOnHit;

  static const LearnedPerks empty = LearnedPerks();

  bool get isEmpty =>
      doubleLoot == 0 && execute == 0 && thorns == 0 && goldOnHit == 0;
}

/// An unlocked active, with rank-scaled power, ready for the combat loop.
@immutable
class UnlockedActive {
  const UnlockedActive({required this.def, required this.rank});

  final SkillDef def;
  final int rank;

  ActiveSkillId get id => def.active!;
  double get manaCost => def.manaCost;
  double get cooldown => def.cooldown;
  double get power => def.activePower * rank;
}

class SkillsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final saved = savedSection(ref, 'skills');
    if (saved == null) return const {};

    final kept = <String, int>{};
    var orphaned = 0;
    for (final e in saved.entries) {
      if (e.value is! num) continue;
      final rank = (e.value as num).toInt();
      if (rank <= 0) continue;
      if (skillCatalog.containsKey(e.key)) {
        kept[e.key] = rank;
      } else {
        orphaned += rank;
      }
    }
    if (orphaned > 0) {
      // Old tree ids are dropped; give the points back after this build.
      Future.microtask(() {
        if (!ref.mounted) return;
        ref.read(playerProvider.notifier).refundSkillPoints(orphaned);
      });
    }
    return kept;
  }

  int rankOf(String id) => state[id] ?? 0;

  int goldFor(SkillDef def) => def.goldForRank(rankOf(def.id) + 1);

  /// Null when [def] can be learned, otherwise the reason it is blocked.
  SkillBlock? blockFor(SkillDef def) {
    final player = ref.read(playerProvider);
    if (rankOf(def.id) >= def.maxRank) return SkillBlock.maxRank;
    if (player.level < def.requiredLevel) return SkillBlock.levelTooLow;
    if (def.requires.any((id) => rankOf(id) <= 0)) {
      return SkillBlock.missingPrereq;
    }
    if (player.skillPoints < def.skillPointCost) return SkillBlock.noPoints;
    if (player.gold < goldFor(def)) return SkillBlock.noGold;
    return null;
  }

  bool learn(String id) {
    final def = skillCatalog[id];
    if (def == null || blockFor(def) != null) return false;
    final gold = goldFor(def);
    if (!ref
        .read(playerProvider.notifier)
        .spendUnlock(gold: gold, skillPoints: def.skillPointCost)) {
      return false;
    }
    state = {...state, id: rankOf(id) + 1};
    return true;
  }

  /// Clears the run's skill tree without refunding points (used on ascension).
  void resetRanks() => state = const {};

  /// Refunds every invested rank back into the player's skill point pool.
  /// Gold already spent on the tree is not returned.
  void respec() {
    final invested = state.values.fold(0, (a, b) => a + b);
    if (invested == 0) return;
    state = const {};
    ref.read(playerProvider.notifier).refundSkillPoints(invested);
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.of(state);
}

final skillsProvider = NotifierProvider<SkillsNotifier, Map<String, int>>(
  SkillsNotifier.new,
);

/// Total ranks invested, shown in the tree header.
final skillPointsSpentProvider = Provider<int>(
  (ref) => ref.watch(skillsProvider).values.fold(0, (a, b) => a + b),
);

/// Combined stat bonus from every learned booster (and any per-rank stats).
final skillBundleProvider = Provider<StatBundle>((ref) {
  final ranks = ref.watch(skillsProvider);
  var bundle = StatBundle.empty;
  for (final entry in ranks.entries) {
    final def = skillCatalog[entry.key];
    if (def == null || entry.value <= 0) continue;
    bundle = bundle + def.bonusAt(entry.value);
  }
  return bundle;
});

final learnedPerksProvider = Provider<LearnedPerks>((ref) {
  final ranks = ref.watch(skillsProvider);
  var doubleLoot = 0.0;
  var execute = 0.0;
  var thorns = 0.0;
  var goldOnHit = 0.0;
  for (final entry in ranks.entries) {
    final def = skillCatalog[entry.key];
    if (def == null || def.perk == null || entry.value <= 0) continue;
    final amount = def.perkPerRank * entry.value;
    switch (def.perk!) {
      case PerkEffect.doubleLoot:
        doubleLoot += amount;
      case PerkEffect.execute:
        execute += amount;
      case PerkEffect.thorns:
        thorns += amount;
      case PerkEffect.goldOnHit:
        goldOnHit += amount;
    }
  }
  return LearnedPerks(
    doubleLoot: doubleLoot.clamp(0.0, 0.8),
    execute: execute,
    thorns: thorns.clamp(0.0, 0.6),
    goldOnHit: goldOnHit,
  );
});

final unlockedActivesProvider = Provider<List<UnlockedActive>>((ref) {
  final ranks = ref.watch(skillsProvider);
  final out = <UnlockedActive>[];
  for (final entry in ranks.entries) {
    final def = skillCatalog[entry.key];
    if (def == null || def.active == null || entry.value <= 0) continue;
    out.add(UnlockedActive(def: def, rank: entry.value));
  }
  return out;
});
