import 'dart:math';

import 'package:flutter/foundation.dart';

/// Outcome of a single swing.
@immutable
class AttackResult {
  const AttackResult({
    required this.damage,
    required this.dodged,
    required this.crit,
    this.fireDamage = 0,
  });

  static const AttackResult miss = AttackResult(
    damage: 0,
    dodged: true,
    crit: false,
  );

  final double damage;
  final bool dodged;
  final bool crit;

  /// Post-armour fire portion included in [damage].
  final double fireDamage;
}

/// Rolls one attack: dodge check, damage roll, crit, then armor mitigation.
///
/// Armor uses the classic diminishing curve `100 / (100 + armor)` so stacking
/// armour never reaches full immunity.
AttackResult rollAttack({
  required Random rng,
  required double damageMin,
  required double damageMax,
  required double critChance,
  required double critMultiplier,
  required double targetArmor,
  required double targetDodge,
  double fireDamage = 0,
}) {
  if (rng.nextDouble() < targetDodge) return AttackResult.miss;

  var damage = damageMin + rng.nextDouble() * (damageMax - damageMin);
  final crit = rng.nextDouble() < critChance;
  if (crit) damage *= critMultiplier;
  damage += fireDamage;

  final mitigated = 100 / (100 + max(0, targetArmor));
  damage *= mitigated;
  return AttackResult(
    damage: max(1, damage),
    dodged: false,
    crit: crit,
    fireDamage: fireDamage * mitigated,
  );
}

/// Cuts incoming fire after armour. [fireResist] of 1.0 is full immunity.
double applyFireResist(
  double damage, {
  required bool fireHit,
  required double fireResist,
}) {
  if (!fireHit || fireResist <= 0) return damage;
  return max(0.0, damage * (1 - fireResist.clamp(0.0, 1.0)));
}

/// Total XP required to advance from [level] to `level + 1`.
int xpToNextLevel(int level) => (50 * pow(level, 1.55)).round() + 50 * level;

/// Skill points granted per level up.
const int skillPointsPerLevel = 1;
