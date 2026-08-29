import 'package:flutter/foundation.dart';

/// Primary attributes the player allocates points into on level up.
enum Attribute {
  strength,
  agility,
  endurance,
  intelligence;

  String get label => switch (this) {
    Attribute.strength => 'Strength',
    Attribute.agility => 'Agility',
    Attribute.endurance => 'Endurance',
    Attribute.intelligence => 'Intelligence',
  };

  String get short => switch (this) {
    Attribute.strength => 'STR',
    Attribute.agility => 'AGI',
    Attribute.endurance => 'END',
    Attribute.intelligence => 'INT',
  };

  String get blurb => switch (this) {
    Attribute.strength => 'Raises weapon damage.',
    Attribute.agility => 'Raises attack speed and dodge.',
    Attribute.endurance => 'Raises max HP, regen and armor.',
    Attribute.intelligence => 'Raises mana and magic damage.',
  };
}

/// Every quantity an item or skill is allowed to modify.
///
/// Keys where [StatKey.fractional] is true store a 0..1 ratio in
/// [StatBundle.flat] (0.05 renders as "+5%").
enum StatKey {
  maxHp,
  hpRegen,
  maxMana,
  manaRegen,
  damage,
  magicDamage,
  fireDamage,
  attackSpeed,
  armor,
  dodge,
  crit,
  critDamage,
  lifeSteal,
  goldFind,
  xpGain,
  lootFind,
  fireResist,
  strength,
  agility,
  endurance,
  intelligence;

  bool get fractional => switch (this) {
    StatKey.dodge ||
    StatKey.crit ||
    StatKey.critDamage ||
    StatKey.lifeSteal ||
    StatKey.goldFind ||
    StatKey.xpGain ||
    StatKey.lootFind ||
    StatKey.fireResist => true,
    _ => false,
  };

  String get label => switch (this) {
    StatKey.maxHp => 'Max HP',
    StatKey.hpRegen => 'HP Regen',
    StatKey.maxMana => 'Max Mana',
    StatKey.manaRegen => 'Mana Regen',
    StatKey.damage => 'Damage',
    StatKey.magicDamage => 'Magic Damage',
    StatKey.fireDamage => 'Fire Damage',
    StatKey.attackSpeed => 'Attack Speed',
    StatKey.armor => 'Armor',
    StatKey.dodge => 'Dodge',
    StatKey.crit => 'Crit Chance',
    StatKey.critDamage => 'Crit Damage',
    StatKey.lifeSteal => 'Life Steal',
    StatKey.goldFind => 'Gold Find',
    StatKey.xpGain => 'XP Gain',
    StatKey.lootFind => 'Loot Find',
    StatKey.fireResist => 'Fire Resist',
    StatKey.strength => 'Strength',
    StatKey.agility => 'Agility',
    StatKey.endurance => 'Endurance',
    StatKey.intelligence => 'Intelligence',
  };

  Attribute? get asAttribute => switch (this) {
    StatKey.strength => Attribute.strength,
    StatKey.agility => Attribute.agility,
    StatKey.endurance => Attribute.endurance,
    StatKey.intelligence => Attribute.intelligence,
    _ => null,
  };
}

/// A set of additive and multiplicative stat modifiers.
///
/// Contributions from gear and skills are summed into one bundle before the
/// character sheet is resolved, so ordering never affects the result.
@immutable
class StatBundle {
  const StatBundle({this.flat = const {}, this.pct = const {}});

  final Map<StatKey, double> flat;
  final Map<StatKey, double> pct;

  static const StatBundle empty = StatBundle();

  bool get isEmpty => flat.isEmpty && pct.isEmpty;

  StatBundle operator +(StatBundle other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return StatBundle(
      flat: _merge(flat, other.flat),
      pct: _merge(pct, other.pct),
    );
  }

  StatBundle operator *(double factor) {
    if (isEmpty || factor == 1) return this;
    return StatBundle(
      flat: {for (final e in flat.entries) e.key: e.value * factor},
      pct: {for (final e in pct.entries) e.key: e.value * factor},
    );
  }

  static Map<StatKey, double> _merge(
    Map<StatKey, double> a,
    Map<StatKey, double> b,
  ) {
    final out = Map<StatKey, double>.of(a);
    for (final e in b.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
    return out;
  }

  /// Human readable lines such as `+12 Armor` or `+5% Crit Chance`.
  List<String> describe() {
    final lines = <String>[];
    for (final key in StatKey.values) {
      final f = flat[key];
      if (f != null && f != 0) lines.add('${_sign(f)}${_fmtFlat(key, f)}');
      final p = pct[key];
      if (p != null && p != 0) {
        lines.add('${_sign(p)}${(p * 100).toStringAsFixed(0)}% ${key.label}');
      }
    }
    return lines;
  }

  static String _sign(double v) => v < 0 ? '-' : '+';

  static String _fmtFlat(StatKey key, double v) {
    final a = v.abs();
    if (key.fractional) {
      return '${_trim(a * 100)}% ${key.label}';
    }
    return '${_trim(a)} ${key.label}';
  }

  static String _trim(double v) {
    if ((v - v.roundToDouble()).abs() < 0.005) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}

/// A fully resolved character sheet used by the combat simulation.
@immutable
class CombatStats {
  const CombatStats({
    required this.attributes,
    required this.maxHp,
    required this.hpRegen,
    required this.maxMana,
    required this.manaRegen,
    required this.damageMin,
    required this.damageMax,
    required this.magicDamage,
    required this.fireDamage,
    required this.attackSpeed,
    required this.armor,
    required this.dodge,
    required this.crit,
    required this.critMultiplier,
    required this.lifeSteal,
    required this.goldFind,
    required this.xpGain,
    required this.lootFind,
    this.fireResist = 0,
  });

  final Map<Attribute, int> attributes;

  /// Hit points at full health.
  final double maxHp;

  /// Hit points restored per second while in combat.
  final double hpRegen;

  final double maxMana;
  final double manaRegen;

  final double damageMin;
  final double damageMax;

  /// Spell power used by unlocked active skills, and a slice of auto-attacks.
  final double magicDamage;

  /// Flat fire damage added to every landed auto-attack.
  final double fireDamage;

  /// Attacks per second.
  final double attackSpeed;
  final double armor;

  /// 0..1 chance to avoid an incoming hit entirely.
  final double dodge;

  /// 0..1 chance for an outgoing hit to crit.
  final double crit;

  /// Damage multiplier applied on a crit (1.5 == 150%).
  final double critMultiplier;

  /// 0..1 fraction of damage dealt that is returned as healing.
  final double lifeSteal;

  final double goldFind;
  final double xpGain;
  final double lootFind;

  /// 0..1 reduction applied to incoming fire-tagged hits.
  final double fireResist;

  double get averageDamage => (damageMin + damageMax) / 2;

  /// Expected damage per second including crits and flat fire.
  ///
  /// Fire is applied after the crit roll and before armour, so it does not
  /// scale with crit chance.
  double get dps =>
      (averageDamage * (1 + crit * (critMultiplier - 1)) + fireDamage) *
      attackSpeed;

  /// Fraction of incoming damage that gets through [armor].
  double get damageTaken => 100 / (100 + armor);

  /// Rough survivability score, useful for comparing gear sets.
  double get effectiveHp => maxHp / damageTaken / (1 - dodge).clamp(0.01, 1.0);

  /// Applies shop booster multipliers without touching the rest of the sheet.
  CombatStats scaledGains({double xp = 1, double loot = 1}) {
    if (xp == 1 && loot == 1) return this;
    return CombatStats(
      attributes: attributes,
      maxHp: maxHp,
      hpRegen: hpRegen,
      maxMana: maxMana,
      manaRegen: manaRegen,
      damageMin: damageMin,
      damageMax: damageMax,
      magicDamage: magicDamage,
      fireDamage: fireDamage,
      attackSpeed: attackSpeed,
      armor: armor,
      dodge: dodge,
      crit: crit,
      critMultiplier: critMultiplier,
      lifeSteal: lifeSteal,
      goldFind: goldFind,
      xpGain: xpGain * xp,
      lootFind: lootFind * loot,
      fireResist: fireResist,
    );
  }

  /// Alchemy tonics stacked on top of the resolved sheet.
  CombatStats withAlchemy({bool berserk = false, bool ward = false}) {
    if (!berserk && !ward) return this;
    return CombatStats(
      attributes: attributes,
      maxHp: maxHp * (ward ? 1.08 : 1),
      hpRegen: hpRegen,
      maxMana: maxMana,
      manaRegen: manaRegen,
      damageMin: damageMin * (berserk ? 1.25 : 1),
      damageMax: damageMax * (berserk ? 1.25 : 1),
      magicDamage: magicDamage * (berserk ? 1.1 : 1),
      fireDamage: fireDamage,
      attackSpeed: (attackSpeed * (berserk ? 1.12 : 1)).clamp(0.2, 5.0),
      armor: armor + (ward ? 48 : 0),
      dodge: dodge,
      crit: crit,
      critMultiplier: critMultiplier,
      lifeSteal: lifeSteal,
      goldFind: goldFind,
      xpGain: xpGain,
      lootFind: lootFind,
      fireResist: fireResist,
    );
  }

  static const CombatStats zero = CombatStats(
    attributes: {},
    maxHp: 1,
    hpRegen: 0,
    maxMana: 1,
    manaRegen: 0,
    damageMin: 0,
    damageMax: 0,
    magicDamage: 0,
    fireDamage: 0,
    attackSpeed: 1,
    armor: 0,
    dodge: 0,
    crit: 0,
    critMultiplier: 1.5,
    lifeSteal: 0,
    goldFind: 1,
    xpGain: 1,
    lootFind: 1,
    fireResist: 0,
  );
}

/// Turns a level, allocated attributes and a pile of modifiers into a
/// [CombatStats] sheet.
///
/// Attributes resolve first so that gear granting `+5 Strength` also feeds the
/// damage that strength provides.
CombatStats resolveStats({
  required int level,
  required Map<Attribute, int> allocated,
  required StatBundle bundle,
}) {
  double value(StatKey key, double base) {
    final flat = bundle.flat[key] ?? 0;
    final pct = bundle.pct[key] ?? 0;
    return (base + flat) * (1 + pct);
  }

  final attrs = <Attribute, int>{};
  for (final attr in Attribute.values) {
    final key = StatKey.values.firstWhere((k) => k.asAttribute == attr);
    final resolved = value(key, (allocated[attr] ?? 0).toDouble());
    attrs[attr] = resolved.round().clamp(0, 1 << 30);
  }

  final str = attrs[Attribute.strength]!.toDouble();
  final agi = attrs[Attribute.agility]!.toDouble();
  final end = attrs[Attribute.endurance]!.toDouble();
  final intel = attrs[Attribute.intelligence]!.toDouble();

  final maxHp = value(StatKey.maxHp, 60 + level * 10 + end * 8).clamp(1.0, 1e9);
  final physical = value(
    StatKey.damage,
    4 + level * 0.6 + str * 0.9,
  ).clamp(1.0, 1e9);
  final magic = value(
    StatKey.magicDamage,
    2 + level * 0.25 + intel * 1.0,
  ).clamp(0.0, 1e9);
  // A slice of spell power rides on every swing so Intelligence is never idle.
  final damage = physical + magic * 0.25;

  return CombatStats(
    attributes: attrs,
    maxHp: maxHp,
    hpRegen: value(StatKey.hpRegen, 0.5 + end * 0.05).clamp(0.0, 1e6),
    maxMana: value(StatKey.maxMana, 20 + level * 2 + intel * 4).clamp(1.0, 1e9),
    manaRegen: value(StatKey.manaRegen, 0.8 + intel * 0.12).clamp(0.0, 1e6),
    damageMin: damage * 0.85,
    damageMax: damage * 1.15,
    magicDamage: magic,
    fireDamage: value(StatKey.fireDamage, 0).clamp(0.0, 1e6),
    attackSpeed: value(StatKey.attackSpeed, 0.8 + agi * 0.01).clamp(0.2, 5.0),
    armor: value(StatKey.armor, level * 1.5 + end * 0.6).clamp(0.0, 1e6),
    dodge: value(StatKey.dodge, 0.02 + agi * 0.002).clamp(0.0, 0.65),
    crit: value(StatKey.crit, 0.05 + agi * 0.0025).clamp(0.0, 0.9),
    critMultiplier: value(StatKey.critDamage, 1.5).clamp(1.0, 20.0),
    lifeSteal: value(StatKey.lifeSteal, 0).clamp(0.0, 0.5),
    goldFind: value(StatKey.goldFind, 1).clamp(0.1, 100.0),
    xpGain: value(StatKey.xpGain, 1).clamp(0.1, 100.0),
    lootFind: value(StatKey.lootFind, 1).clamp(0.1, 100.0),
    fireResist: value(StatKey.fireResist, 0).clamp(0.0, 1.0),
  );
}
