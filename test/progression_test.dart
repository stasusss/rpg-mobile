import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/data/items_data.dart';
import 'package:idle_rpg/data/locations_data.dart';
import 'package:idle_rpg/data/skills_data.dart';
import 'package:idle_rpg/models/combat_math.dart';
import 'package:idle_rpg/models/item.dart';
import 'package:idle_rpg/models/item_set.dart';
import 'package:idle_rpg/models/mastery.dart';
import 'package:idle_rpg/models/stats.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/player_provider.dart';
import 'package:idle_rpg/providers/player_stats_provider.dart';
import 'package:idle_rpg/providers/progress_provider.dart';
import 'package:idle_rpg/providers/skills_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';

import 'helpers.dart';

void main() {
  group('levelling', () {
    test('a single level up grants skill points only', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      final before = container.read(playerProvider);

      final gained = player.gainXp(xpToNextLevel(before.level));

      final after = container.read(playerProvider);
      expect(gained, 1);
      expect(after.level, before.level + 1);
      expect(after.attributePoints, before.attributePoints);
      expect(after.skillPoints, before.skillPoints + skillPointsPerLevel);
    });

    test('a large XP dump resolves multiple levels at once', () {
      final container = createContainer();
      final gained = container.read(playerProvider.notifier).gainXp(100000);

      expect(gained, greaterThan(5));
      expect(container.read(playerProvider).level, gained + 1);
    });

    test('leftover XP carries into the next level', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      final need = xpToNextLevel(1);

      player.gainXp(need + 7);
      expect(container.read(playerProvider).xp, 7);
    });

    test('hits dealt raise weapon mastery and attack power', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      final damageBefore = container.read(combatStatsProvider).damageMax;
      final need = ActionMastery.hitsForNextWeapon(1);

      for (var i = 0; i < need; i++) {
        player.recordHit();
      }

      final mastery = container.read(playerStatsProvider);
      expect(mastery.weaponMastery, 1);
      expect(
        container.read(combatStatsProvider).damageMax,
        greaterThan(damageBefore),
      );
    });

    test('damage taken raises armor mastery and max HP', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      final hpBefore = container.read(combatStatsProvider).maxHp;
      final need = ActionMastery.damageForNextArmor(1);

      var absorbed = 0;
      while (absorbed < need) {
        player.recordDamageTaken(10);
        absorbed += 10;
      }

      expect(container.read(playerStatsProvider).armorMastery, greaterThan(0));
      expect(container.read(combatStatsProvider).maxHp, greaterThan(hpBefore));
    });

    test('kills raise character rank and intelligence', () {
      final container = createContainer();
      final before = container.read(combatStatsProvider);
      final need = ActionMastery.killsForNextRank(1);

      for (var i = 0; i < need; i++) {
        container.read(playerProvider.notifier).recordKill();
      }

      expect(container.read(playerStatsProvider).characterRank, 1);
      final after = container.read(combatStatsProvider);
      expect(after.maxMana, greaterThan(before.maxMana));
      expect(after.magicDamage, greaterThan(before.magicDamage));
    });

    test('gold cannot be overspent', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      final gold = container.read(playerProvider).gold;

      expect(player.spendGold(gold + 1), isFalse);
      expect(container.read(playerProvider).gold, gold);
      expect(player.spendGold(gold), isTrue);
      expect(container.read(playerProvider).gold, 0);
    });
  });

  group('skill tree', () {
    test('the first node of a branch is learnable immediately', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);

      expect(skills.learn('iron_arms'), isTrue);
      expect(container.read(skillsProvider)['iron_arms'], 1);
      expect(container.read(playerProvider).skillPoints, 0);
    });

    test('deeper nodes require their prerequisite', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(500);

      expect(
        skills.blockFor(skillById('heavy_blow')),
        SkillBlock.missingPrereq,
      );
      skills.learn('iron_arms');
      expect(skills.blockFor(skillById('heavy_blow')), isNull);
    });

    test('paid nodes charge gold as well as a skill point', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      skills.learn('iron_arms');

      expect(skills.blockFor(skillById('heavy_blow')), SkillBlock.noGold);
      player.gainGold(50);
      final goldBefore = container.read(playerProvider).gold;
      expect(skills.learn('heavy_blow'), isTrue);
      expect(container.read(playerProvider).gold, goldBefore - 50);
    });

    test('nodes respect their level gate', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);

      skills.learn('iron_arms');
      expect(skills.blockFor(skillById('heavy_blow')), SkillBlock.levelTooLow);
    });

    test('ranks cap at maxRank', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);
      container.read(playerProvider.notifier).gainXp(500000);

      final def = skillById('iron_arms');
      for (var i = 0; i < def.maxRank + 3; i++) {
        skills.learn(def.id);
      }
      expect(container.read(skillsProvider)[def.id], def.maxRank);
      expect(skills.blockFor(def), SkillBlock.maxRank);
    });

    test('learned skills feed the combat sheet', () {
      final container = createContainer();
      final strBefore = container
          .read(combatStatsProvider)
          .attributes[Attribute.strength]!;

      container.read(skillsProvider.notifier).learn('iron_arms');
      expect(
        container.read(combatStatsProvider).attributes[Attribute.strength],
        strBefore + 3,
      );
    });

    test('a booster node raises live auto-battler damage', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      player.gainXp(100000);
      player.gainGold(50);
      final skills = container.read(skillsProvider.notifier);
      skills.learn('iron_arms');
      final dmgBefore = container.read(combatStatsProvider).averageDamage;

      expect(skills.learn('heavy_blow'), isTrue);
      expect(
        container.read(combatStatsProvider).averageDamage,
        greaterThan(dmgBefore),
      );
    });

    test('perk ranks accumulate on the learned-perks sheet', () {
      final container = createContainer();
      final player = container.read(playerProvider.notifier);
      player.gainXp(500000);
      player.gainGold(5000);
      final skills = container.read(skillsProvider.notifier);
      expect(skills.learn('fleet_foot'), isTrue);
      expect(skills.learn('quick_draw'), isTrue);
      expect(skills.learn('double_loot'), isTrue);

      expect(
        container.read(learnedPerksProvider).doubleLoot,
        closeTo(0.10, 1e-9),
      );
    });

    test('respec returns every point', () {
      final container = createContainer();
      final skills = container.read(skillsProvider.notifier);
      container.read(playerProvider.notifier).gainXp(100000);

      skills.learn('iron_arms');
      skills.learn('fleet_foot');
      final remaining = container.read(playerProvider).skillPoints;

      skills.respec();
      expect(container.read(skillsProvider), isEmpty);
      expect(container.read(playerProvider).skillPoints, remaining + 2);
    });
  });

  group('map unlocks', () {
    test('each zone lists the materials its enemies drop', () {
      expect(
        materialsIn(locationById('goblin_woods')).map((i) => i.id),
        contains('wolf_pelt'),
      );
      expect(
        materialsIn(locationById('skeleton_crypt')).map((i) => i.id),
        contains('bone'),
      );
      expect(locationById('skeleton_crypt').recommendedLevel, 17);
    });

    test('only the starting node is open at level one', () {
      final container = createContainer();
      final unlocks = container.read(locationUnlocksProvider);

      expect(unlocks['meadow'], isNull);
      expect(unlocks['goblin_woods'], isNotNull);
    });

    test('travel is refused while a node is locked', () {
      final container = createContainer();
      final progress = container.read(progressProvider.notifier);

      expect(progress.travelTo('emberpeak'), isFalse);
      expect(container.read(progressProvider).currentLocationId, 'meadow');
    });

    test('kills plus level open the next node', () {
      final container = createContainer();
      final progress = container.read(progressProvider.notifier);
      container.read(playerProvider.notifier).gainXp(100000);

      for (var i = 0; i < 12; i++) {
        progress.recordKill('green_slime');
      }

      expect(container.read(locationUnlocksProvider)['goblin_woods'], isNull);
      expect(progress.travelTo('goblin_woods'), isTrue);
      expect(
        container.read(progressProvider).currentLocationId,
        'goblin_woods',
      );
    });

    test('lock reason reports kill progress', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(100000);
      container.read(progressProvider.notifier).recordKill('green_slime');

      expect(
        container.read(locationUnlocksProvider)['goblin_woods'],
        contains('1/12'),
      );
    });

    test('bestiary tracks discovered enemies', () {
      final container = createContainer();
      final before = container.read(bestiaryProgressProvider);

      container.read(progressProvider.notifier).recordKill('green_slime');

      expect(container.read(bestiaryProgressProvider).seen, before.seen + 1);
      expect(container.read(progressProvider).hasSeen('green_slime'), isTrue);
      expect(container.read(progressProvider).hasSeen('ash_drake'), isFalse);
    });
  });

  group('persistence', () {
    test('a saved blob restores level, gold, gear and progress', () {
      final source = createContainer();
      source.read(playerProvider.notifier).gainXp(100000);
      source.read(playerProvider.notifier).gainGold(500);
      source.read(playerProvider.notifier).recordHit();
      source.read(playerProvider.notifier).recordDamageTaken(25);
      source.read(inventoryProvider.notifier).add('dragon_scale', 4);
      source.read(skillsProvider.notifier).learn('iron_hide');
      source.read(progressProvider.notifier).recordKill('grey_wolf');

      final blob = {
        'player': source.read(playerProvider).toJson(),
        'inventory': source.read(inventoryProvider).toJson(),
        'skills': source.read(skillsProvider),
        'progress': source.read(progressProvider).toJson(),
      };

      final restored = createContainer(save: blob);
      expect(
        restored.read(playerProvider).level,
        source.read(playerProvider).level,
      );
      expect(
        restored.read(playerProvider).gold,
        source.read(playerProvider).gold,
      );
      expect(restored.read(playerProvider).hitsDealt, 1);
      expect(restored.read(playerProvider).damageTaken, 25);
      expect(restored.read(inventoryProvider).countOf('dragon_scale'), 4);
      expect(restored.read(skillsProvider)['iron_hide'], 1);
      expect(restored.read(progressProvider).killsOf('grey_wolf'), 1);
      expect(
        restored.read(inventoryProvider).equipped[EquipSlot.weapon]?.itemId,
        'ember_blade',
      );
    });

    test('unknown ids in a save are dropped instead of crashing', () {
      final restored = createContainer(
        save: {
          'inventory': {
            'bag': [
              {'uid': 'i1', 'itemId': 'not_a_real_item', 'quantity': 3},
              {'uid': 'i2', 'itemId': 'bone', 'quantity': 2},
            ],
            'equipped': {
              'weapon': {'uid': 'i3', 'itemId': 'also_fake'},
            },
            'capacity': 48,
            'nextUid': 9,
          },
        },
      );

      final inventory = restored.read(inventoryProvider);
      expect(inventory.bag.length, 1);
      expect(inventory.countOf('bone'), 2);
      expect(inventory.equipped[EquipSlot.weapon], isNull);
    });
  });

  group('action mastery', () {
    test('thresholds follow the authored triangular costs', () {
      expect(ActionMastery.hitsForNextWeapon(1), 75);
      expect(ActionMastery.damageForNextArmor(1), 120);
      expect(ActionMastery.killsForNextRank(1), 14);
      expect(ActionMastery.cumulative(1, ActionMastery.hitsForNextWeapon), 75);
      expect(ActionMastery.cumulative(2, ActionMastery.hitsForNextWeapon), 175);

      const mid = ActionMastery(
        hitsDealt: 75,
        damageTaken: 0,
        enemiesKilled: 0,
      );
      expect(mid.weaponMastery, 1);
      expect(mid.hitsIntoLevel, 0);
      expect(mid.hitsNeeded, 100);
    });

    test('legacy attribute spend seeds mastery counters', () {
      final restored = createContainer(
        save: {
          'player': {
            'level': 4,
            'allocated': {
              'strength': 7,
              'endurance': 6,
              'agility': 5,
              'intelligence': 5,
            },
          },
        },
      );

      final player = restored.read(playerProvider);
      expect(
        player.hitsDealt,
        ActionMastery.cumulative(2, ActionMastery.hitsForNextWeapon),
      );
      expect(
        player.damageTaken,
        ActionMastery.cumulative(1, ActionMastery.damageForNextArmor),
      );
      expect(restored.read(playerStatsProvider).weaponMastery, 2);
      expect(restored.read(playerStatsProvider).armorMastery, 1);
    });
  });

  group('item rarity and sets', () {
    test('rarity scales authored item bonuses', () {
      final common = itemById('wooden_shield');
      expect(common.rarity.statMultiplier, 1.0);
      expect(common.effectiveBonuses.flat[StatKey.armor], 6);

      final uncommon = itemById('ember_blade');
      expect(uncommon.rarity, ItemRarity.uncommon);
      expect(
        uncommon.effectiveBonuses.flat[StatKey.damage],
        closeTo(4 * 1.12, 1e-9),
      );
    });

    test('starter kit wakes the Ashen Warden 2-piece bonus', () {
      final container = createContainer();
      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.ashenWarden);

      expect(progress.equipped, 2);
      expect(progress.hasTwo, isTrue);
      expect(progress.hasFour, isFalse);
      expect(progress.bundle.flat[StatKey.maxHp], 36);
      expect(container.read(combatStatsProvider).fireDamage, 0);
    });

    test('four Ashen Warden pieces grant fire damage', () {
      final container = createContainer();
      final inventory = container.read(inventoryProvider.notifier);
      final bag = container.read(inventoryProvider).bag;

      inventory.equip(bag.firstWhere((e) => e.itemId == 'leather_cap').uid);
      inventory.equip(bag.firstWhere((e) => e.itemId == 'worn_boots').uid);

      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.ashenWarden);
      expect(progress.hasFour, isTrue);
      expect(container.read(combatStatsProvider).fireDamage, 3);
    });

    test('Ironclad Behemoth 4-piece grants damage reflection', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(100000);
      final inventory = container.read(inventoryProvider.notifier);

      for (final id in [
        'iron_sword',
        'iron_helm',
        'iron_shield',
        'chain_mail',
      ]) {
        inventory.add(id, 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == id)
            .uid;
        expect(inventory.equip(uid), isTrue);
      }

      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.ironcladBehemoth);
      expect(progress.hasFour, isTrue);
      expect(container.read(setThornsProvider), closeTo(0.10, 1e-9));
    });

    test('Bloodthirster 4-piece grants life steal and crit damage', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(10000000);
      final inventory = container.read(inventoryProvider.notifier);

      for (final id in [
        'blood_fang',
        'crimson_hood',
        'sanguine_mail',
        'gore_treads',
      ]) {
        inventory.add(id, 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == id)
            .uid;
        expect(inventory.equip(uid), isTrue);
      }

      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.bloodthirster);
      expect(progress.hasFour, isTrue);
      expect(progress.bundle.flat[StatKey.lifeSteal], closeTo(0.10, 1e-9));
      expect(progress.bundle.flat[StatKey.critDamage], closeTo(0.25, 1e-9));
    });

    test('Archmage Arcana 4-piece grants mana regen and spell power', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(10000000);
      final inventory = container.read(inventoryProvider.notifier);

      for (final id in [
        'arcane_staff',
        'mage_circlet',
        'scholar_robes',
        'focus_band',
      ]) {
        inventory.add(id, 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == id)
            .uid;
        expect(inventory.equip(uid), isTrue);
      }

      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.archmageArcana);
      expect(progress.hasFour, isTrue);
      expect(progress.bundle.flat[StatKey.manaRegen], closeTo(5, 1e-9));
      expect(progress.bundle.flat[StatKey.magicDamage], closeTo(18, 1e-9));
    });

    test('Volcanic Drake 4-piece grants fire immunity', () {
      final container = createContainer();
      container.read(playerProvider.notifier).gainXp(10000000);
      final inventory = container.read(inventoryProvider.notifier);

      for (final id in [
        'drake_cleaver',
        'magma_visor',
        'basalt_carapace',
        'lava_treads',
      ]) {
        inventory.add(id, 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == id)
            .uid;
        expect(inventory.equip(uid), isTrue);
      }

      final progress = container
          .read(setBonusProvider)
          .firstWhere((s) => s.def.id == ItemSetId.volcanicDrake);
      expect(progress.hasFour, isTrue);
      expect(progress.bundle.flat[StatKey.armor], closeTo(180, 1e-9));
      expect(container.read(combatStatsProvider).fireResist, 1.0);
    });
  });
}
