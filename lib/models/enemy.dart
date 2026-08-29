import 'package:flutter/material.dart';

/// Body plan used by the procedural sprite painter in `flame/`.
enum BodyPlan { humanoid, quadruped, blob, flyer, hulk, arachnid }

/// Everything the renderer needs to draw an enemy without image assets.
@immutable
class EnemyVisual {
  const EnemyVisual({
    required this.plan,
    required this.body,
    required this.accent,
    this.eye = const Color(0xFFFF5252),
    this.scale = 1.0,
    this.horns = false,
    this.wings = false,
    this.hasWeapon = false,
  });

  final BodyPlan plan;
  final Color body;
  final Color accent;
  final Color eye;

  /// Multiplier on the base 1-unit sprite height.
  final double scale;
  final bool horns;
  final bool wings;
  final bool hasWeapon;
}

/// A weighted loot table row.
@immutable
class LootDrop {
  const LootDrop({
    required this.itemId,
    required this.chance,
    this.min = 1,
    this.max = 1,
  });

  final String itemId;

  /// 0..1 base chance before the player's Loot Find multiplier.
  final double chance;
  final int min;
  final int max;
}

/// Scripted tricks reserved for elites and bosses.
enum BossAbility { enrage, shieldPhase, poisonCloud }

/// Immutable enemy blueprint. Live combatants are `EnemyInstance`.
@immutable
class EnemyDef {
  const EnemyDef({
    required this.id,
    required this.name,
    required this.level,
    required this.maxHp,
    required this.damage,
    required this.attackSpeed,
    required this.visual,
    this.armor = 0,
    this.dodge = 0,
    this.crit = 0.03,
    this.xp = 10,
    this.goldMin = 1,
    this.goldMax = 3,
    this.loot = const [],
    this.isBoss = false,
    this.isElite = false,
    this.dealsFire = false,
    this.abilities = const [],
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final int level;
  final double maxHp;
  final double damage;

  /// Attacks per second.
  final double attackSpeed;
  final double armor;
  final double dodge;
  final double crit;
  final int xp;
  final int goldMin;
  final int goldMax;
  final List<LootDrop> loot;
  final bool isBoss;
  final bool isElite;

  /// Emberpeak swings that [CombatStats.fireResist] can ignore.
  final bool dealsFire;

  /// Scripted elite / boss tricks used by the combat loop.
  final List<BossAbility> abilities;
  final EnemyVisual visual;

  List<BossAbility> get resolvedAbilities {
    if (abilities.isNotEmpty) return abilities;
    if (isBoss || isElite) return const [BossAbility.enrage];
    return const [];
  }

  double get damageMin => damage * 0.85;
  double get damageMax => damage * 1.15;
}

/// A spawned enemy with mutable health, owned by the combat state.
@immutable
class EnemyInstance {
  const EnemyInstance({
    required this.def,
    required this.hp,
    required this.spawnId,
  });

  final EnemyDef def;
  final double hp;

  /// Increments on every spawn so the renderer can tell instances apart.
  final int spawnId;

  double get hpFraction => (hp / def.maxHp).clamp(0.0, 1.0);
  bool get isDead => hp <= 0;

  EnemyInstance copyWith({double? hp}) =>
      EnemyInstance(def: def, hp: hp ?? this.hp, spawnId: spawnId);
}
