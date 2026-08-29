import 'item.dart';
import 'stats.dart';

/// Rough value of one point of each stat, used only to compare two pieces of
/// gear for the same slot (auto-equip and the "upgrade" arrow in the grid).
///
/// This is a heuristic, not the combat model: it keeps auto-equip cheap and
/// predictable without re-resolving the whole character sheet per candidate.
const Map<StatKey, double> _flatWeights = {
  StatKey.damage: 4.0,
  StatKey.maxHp: 0.5,
  StatKey.armor: 0.9,
  StatKey.hpRegen: 3.0,
  StatKey.attackSpeed: 60.0,
  StatKey.dodge: 220.0,
  StatKey.crit: 200.0,
  StatKey.critDamage: 45.0,
  StatKey.lifeSteal: 260.0,
  StatKey.goldFind: 20.0,
  StatKey.xpGain: 25.0,
  StatKey.lootFind: 30.0,
  StatKey.strength: 3.6,
  StatKey.agility: 3.2,
  StatKey.endurance: 4.5,
  StatKey.intelligence: 3.4,
  StatKey.magicDamage: 3.2,
  StatKey.fireDamage: 3.4,
  StatKey.maxMana: 0.4,
  StatKey.manaRegen: 4.0,
  StatKey.fireResist: 90.0,
};

/// Percentage modifiers are scored against a nominal base so that `+10% damage`
/// stays comparable to `+4 damage` across the whole level range.
const Map<StatKey, double> _pctBases = {
  StatKey.damage: 120.0,
  StatKey.maxHp: 90.0,
  StatKey.armor: 80.0,
  StatKey.attackSpeed: 120.0,
  StatKey.hpRegen: 30.0,
};

double gearScore(ItemDef item) {
  final bonuses = item.effectiveBonuses;
  var score = 0.0;
  for (final e in bonuses.flat.entries) {
    score += e.value * (_flatWeights[e.key] ?? 1.0);
  }
  for (final e in bonuses.pct.entries) {
    score += e.value * (_pctBases[e.key] ?? 60.0);
  }
  return score;
}
