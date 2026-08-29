import 'package:flutter/material.dart';

import 'stats.dart';

/// The four columns of the skill tree, one per core attribute.
enum SkillBranch {
  might,
  swift,
  vital,
  arcane;

  String get label => switch (this) {
    SkillBranch.might => 'Might',
    SkillBranch.swift => 'Swift',
    SkillBranch.vital => 'Vital',
    SkillBranch.arcane => 'Arcane',
  };

  Color get color => switch (this) {
    SkillBranch.might => const Color(0xFFEF4444),
    SkillBranch.swift => const Color(0xFF38BDF8),
    SkillBranch.vital => const Color(0xFF34D399),
    SkillBranch.arcane => const Color(0xFFA78BFA),
  };

  IconData get icon => switch (this) {
    SkillBranch.might => Icons.local_fire_department,
    SkillBranch.swift => Icons.bolt,
    SkillBranch.vital => Icons.health_and_safety,
    SkillBranch.arcane => Icons.auto_awesome,
  };
}

/// How a node spends its ranks.
enum SkillNodeKind {
  /// Flat or percent combat stats, e.g. +5 damage.
  booster,

  /// A chance-or-magnitude perk applied by the combat / loot loop.
  perk,

  /// Unlocks an active the auto-battler casts from the mana pool.
  active;

  String get label => switch (this) {
    SkillNodeKind.booster => 'Stat booster',
    SkillNodeKind.perk => 'Passive perk',
    SkillNodeKind.active => 'Active skill',
  };
}

/// Named perk hooks the simulation understands.
enum PerkEffect {
  /// Chance to double a dropped stack.
  doubleLoot,

  /// Extra damage multiplier while the target is below 25% HP.
  execute,

  /// Fraction of incoming damage reflected to the attacker.
  thorns,

  /// Gold granted on every successful auto-attack.
  goldOnHit,
}

/// Actives the auto-battler can fire when mana and cooldown allow.
enum ActiveSkillId {
  powerStrike,
  cleave,
  heal,
  manaBolt,
  nova,
  flameSlash,
  ironWill,
  shadowStrike,
}

/// A node on the skill grid. Bonuses, perk strength and active power all
/// scale linearly with invested rank.
@immutable
class SkillDef {
  const SkillDef({
    required this.id,
    required this.name,
    required this.branch,
    required this.kind,
    required this.col,
    required this.row,
    required this.icon,
    this.description = '',
    this.maxRank = 5,
    this.requires = const [],
    this.requiredLevel = 1,
    this.goldCost = 0,
    this.skillPointCost = 1,
    this.perRank = StatBundle.empty,
    this.perk,
    this.perkPerRank = 0,
    this.active,
    this.manaCost = 0,
    this.cooldown = 0,
    this.activePower = 0,
  });

  final String id;
  final String name;
  final String description;
  final SkillBranch branch;
  final SkillNodeKind kind;

  /// Grid coordinates used by the zoomable tree. Column 0 is Might.
  final int col;
  final int row;

  final int maxRank;

  /// Skill ids that need at least one rank before this node can be learned.
  final List<String> requires;
  final int requiredLevel;

  /// Gold charged for the *next* rank, multiplied by `(currentRank + 1)`.
  final int goldCost;
  final int skillPointCost;

  /// Combat-stat bonus granted by a single rank.
  final StatBundle perRank;
  final IconData icon;

  final PerkEffect? perk;
  final double perkPerRank;

  final ActiveSkillId? active;
  final double manaCost;
  final double cooldown;

  /// Damage multiplier or heal fraction at rank 1.
  final double activePower;

  StatBundle bonusAt(int rank) => perRank * rank.toDouble();

  int goldForRank(int nextRank) => goldCost * nextRank;

  String get kindLabel => kind.label;
}
