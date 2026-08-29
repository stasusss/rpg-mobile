import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/models/combat_math.dart';
import 'package:idle_rpg/models/stats.dart';

void main() {
  const baseAllocation = {
    Attribute.strength: 5,
    Attribute.agility: 5,
    Attribute.endurance: 5,
    Attribute.intelligence: 5,
  };

  group('StatBundle', () {
    test('addition merges flat and percentage entries', () {
      const a = StatBundle(
        flat: {StatKey.damage: 5, StatKey.armor: 10},
        pct: {StatKey.maxHp: 0.1},
      );
      const b = StatBundle(
        flat: {StatKey.damage: 3},
        pct: {StatKey.maxHp: 0.05, StatKey.damage: 0.2},
      );

      final sum = a + b;
      expect(sum.flat[StatKey.damage], 8);
      expect(sum.flat[StatKey.armor], 10);
      expect(sum.pct[StatKey.maxHp], closeTo(0.15, 1e-9));
      expect(sum.pct[StatKey.damage], 0.2);
    });

    test('scaling by rank multiplies every entry', () {
      const perRank = StatBundle(
        flat: {StatKey.crit: 0.025},
        pct: {StatKey.damage: 0.04},
      );

      final atRank3 = perRank * 3;
      expect(atRank3.flat[StatKey.crit], closeTo(0.075, 1e-9));
      expect(atRank3.pct[StatKey.damage], closeTo(0.12, 1e-9));
    });

    test('describe formats fractional keys as percentages', () {
      const bundle = StatBundle(
        flat: {StatKey.crit: 0.05, StatKey.armor: 12},
        pct: {StatKey.damage: 0.1},
      );

      expect(
        bundle.describe(),
        containsAll(['+12 Armor', '+5% Crit Chance', '+10% Damage']),
      );
    });
  });

  group('resolveStats', () {
    test('attribute bonuses feed the stats they govern', () {
      final without = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: StatBundle.empty,
      );
      final withStrength = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: const StatBundle(flat: {StatKey.strength: 10}),
      );

      expect(withStrength.attributes[Attribute.strength], 15);
      expect(withStrength.damageMax, greaterThan(without.damageMax));
    });

    test('intelligence feeds mana and magic damage', () {
      final without = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: StatBundle.empty,
      );
      final withInt = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: const StatBundle(flat: {StatKey.intelligence: 10}),
      );

      expect(withInt.attributes[Attribute.intelligence], 15);
      expect(withInt.maxMana, greaterThan(without.maxMana));
      expect(withInt.magicDamage, greaterThan(without.magicDamage));
    });

    test('percentage modifiers apply after flat ones', () {
      final stats = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: const StatBundle(
          flat: {StatKey.maxHp: 100},
          pct: {StatKey.maxHp: 0.5},
        ),
      );

      // Base is 60 + level*10 + endurance*8 = 110; (110 + 100) * 1.5 = 315.
      expect(stats.maxHp, closeTo(315, 1e-6));
    });

    test('agility raises attack speed and dodge', () {
      final without = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: StatBundle.empty,
      );
      final withAgi = resolveStats(
        level: 1,
        allocated: {...baseAllocation, Attribute.agility: 20},
        bundle: StatBundle.empty,
      );

      expect(withAgi.attackSpeed, greaterThan(without.attackSpeed));
      expect(withAgi.dodge, greaterThan(without.dodge));
    });

    test('dodge and crit stay inside their caps', () {
      final stats = resolveStats(
        level: 99,
        allocated: baseAllocation,
        bundle: const StatBundle(flat: {StatKey.dodge: 5, StatKey.crit: 5}),
      );

      expect(stats.dodge, lessThanOrEqualTo(0.65));
      expect(stats.crit, lessThanOrEqualTo(0.9));
    });

    test('fire damage is resolved from the bundle', () {
      final stats = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: const StatBundle(flat: {StatKey.fireDamage: 10}),
      );

      expect(stats.fireDamage, 10);
    });

    test('dps accounts for crit chance and multiplier', () {
      final stats = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: StatBundle.empty,
      );

      final expected =
          (stats.averageDamage * (1 + stats.crit * (stats.critMultiplier - 1)) +
              stats.fireDamage) *
          stats.attackSpeed;
      expect(stats.dps, closeTo(expected, 1e-9));
    });

    test('dps includes flat fire damage', () {
      final without = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: StatBundle.empty,
      );
      final withFire = resolveStats(
        level: 1,
        allocated: baseAllocation,
        bundle: const StatBundle(flat: {StatKey.fireDamage: 3}),
      );

      expect(
        withFire.dps,
        closeTo(without.dps + 3 * withFire.attackSpeed, 1e-9),
      );
    });
  });

  group('rollAttack', () {
    test('always dodges when dodge chance is total', () {
      final result = rollAttack(
        rng: Random(1),
        damageMin: 10,
        damageMax: 10,
        critChance: 0,
        critMultiplier: 2,
        targetArmor: 0,
        targetDodge: 1,
      );

      expect(result.dodged, isTrue);
      expect(result.damage, 0);
    });

    test('armor reduces damage on the 100/(100+armor) curve', () {
      final unarmored = rollAttack(
        rng: Random(2),
        damageMin: 100,
        damageMax: 100,
        critChance: 0,
        critMultiplier: 2,
        targetArmor: 0,
        targetDodge: 0,
      );
      final armored = rollAttack(
        rng: Random(2),
        damageMin: 100,
        damageMax: 100,
        critChance: 0,
        critMultiplier: 2,
        targetArmor: 100,
        targetDodge: 0,
      );

      expect(unarmored.damage, closeTo(100, 1e-6));
      expect(armored.damage, closeTo(50, 1e-6));
    });

    test('fire damage is applied before armour mitigation', () {
      final unarmored = rollAttack(
        rng: Random(2),
        damageMin: 100,
        damageMax: 100,
        critChance: 0,
        critMultiplier: 2,
        targetArmor: 0,
        targetDodge: 0,
        fireDamage: 20,
      );
      final armored = rollAttack(
        rng: Random(2),
        damageMin: 100,
        damageMax: 100,
        critChance: 0,
        critMultiplier: 2,
        targetArmor: 100,
        targetDodge: 0,
        fireDamage: 20,
      );

      expect(unarmored.damage, closeTo(120, 1e-6));
      expect(armored.damage, closeTo(60, 1e-6));
    });

    test('guaranteed crit multiplies damage', () {
      final result = rollAttack(
        rng: Random(3),
        damageMin: 10,
        damageMax: 10,
        critChance: 1,
        critMultiplier: 3,
        targetArmor: 0,
        targetDodge: 0,
      );

      expect(result.crit, isTrue);
      expect(result.damage, closeTo(30, 1e-6));
    });

    test('damage never drops below one', () {
      final result = rollAttack(
        rng: Random(4),
        damageMin: 1,
        damageMax: 1,
        critChance: 0,
        critMultiplier: 1,
        targetArmor: 100000,
        targetDodge: 0,
      );

      expect(result.damage, greaterThanOrEqualTo(1));
    });
  });

  group('xp curve', () {
    test('requirement grows monotonically', () {
      for (var level = 1; level < 60; level++) {
        expect(xpToNextLevel(level + 1), greaterThan(xpToNextLevel(level)));
      }
    });
  });
}
