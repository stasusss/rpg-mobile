import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/data/items_data.dart';
import 'package:idle_rpg/data/locations_data.dart';
import 'package:idle_rpg/l10n/app_locale.dart';
import 'package:idle_rpg/l10n/l10n.dart';
import 'package:idle_rpg/models/prestige.dart';
import 'package:idle_rpg/providers/achievements_provider.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/player_provider.dart';
import 'package:idle_rpg/providers/prestige_provider.dart';
import 'package:idle_rpg/providers/progress_provider.dart';
import 'package:idle_rpg/providers/save_controller.dart';
import 'package:idle_rpg/providers/save_provider.dart';
import 'package:idle_rpg/providers/skills_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';

import 'helpers.dart';

void main() {
  group('Ash Soul yield', () {
    test('sums location, kills, and crafts, with a floor of one', () {
      expect(
        calculatePrestigeYield(
          highestLocationIndex: 0,
          totalKills: 0,
          itemsCrafted: 0,
        ).total,
        0,
      );
      expect(
        calculatePrestigeYield(
          highestLocationIndex: 0,
          totalKills: 3,
          itemsCrafted: 0,
        ).total,
        1,
      );
      final yield_ = calculatePrestigeYield(
        highestLocationIndex: 2,
        totalKills: 80,
        itemsCrafted: 9,
      );
      expect(yield_.fromLocation, 8);
      expect(yield_.fromKills, 3);
      expect(yield_.fromCrafts, 3);
      expect(yield_.total, 14);
    });
  });

  group('PrestigeNotifier', () {
    test('executeAscension resets the run and keeps meta progress', () async {
      final container = createContainer();
      container.read(saveControllerProvider);

      final player = container.read(playerProvider.notifier);
      player.gainXp(20000);
      player.gainGems(9);
      player.gainGold(400);
      for (var i = 0; i < 50; i++) {
        player.recordKill();
      }
      for (var i = 0; i < 6; i++) {
        player.recordCraft();
      }
      final progress = container.read(progressProvider.notifier);
      for (var i = 0; i < 12; i++) {
        progress.recordKill('green_slime');
      }
      expect(progress.travelTo('goblin_woods'), isTrue);
      expect(container.read(skillsProvider.notifier).learn('iron_arms'), isTrue);

      final beforeLevel = container.read(playerProvider).level;
      expect(beforeLevel, greaterThan(1));

      final ok = await container
          .read(prestigeProvider.notifier)
          .executeAscension();
      await container.read(saveControllerProvider).flushNow();
      expect(ok, isTrue);

      final after = container.read(playerProvider);
      expect(after.level, 1);
      expect(after.xp, 0);
      expect(after.gold, 25);
      expect(after.totalKills, 0);
      expect(after.itemsCrafted, 0);
      expect(after.hitsDealt, 0);
      expect(after.damageTaken, 0);
      expect(after.gems, 9);
      expect(after.skillPoints, 1);

      expect(container.read(progressProvider).currentLocationId, startingLocationId);
      expect(container.read(progressProvider).killsByLocation, isEmpty);
      expect(container.read(skillsProvider), isEmpty);

      final bagIds = [
        for (final e in container.read(inventoryProvider).bag) e.itemId,
      ];
      expect(bagIds, containsAll(starterBag));

      final prestige = container.read(prestigeProvider);
      expect(prestige.ashSouls, greaterThan(0));
      // Location index 1 * 4 + 50~/25 + 6~/3 = 4+2+2 = 8, plus The Persistent.
      expect(prestige.ashSouls, 8 + 3);

      final chronicle = container.read(achievementsProvider);
      expect(chronicle.lifetimePrestiges, 1);
      expect(chronicle.lifetimeKills, 0);
      expect(chronicle.isUnlocked('prestiges_1'), isTrue);
      expect(chronicle.lifetimeGold, greaterThanOrEqualTo(400));
    });

    test('Ember Heritage seeds gold and tier-1 mats on the next life', () async {
      final container = createContainer();
      container.read(saveControllerProvider);
      container.read(prestigeProvider.notifier).awardSouls(20);
      expect(
        container.read(prestigeProvider.notifier).buyPerk(MetaPerk.emberHeritage),
        isTrue,
      );

      final player = container.read(playerProvider.notifier);
      player.recordKill();
      await container.read(prestigeProvider.notifier).executeAscension();
      await container.read(saveControllerProvider).flushNow();

      expect(container.read(playerProvider).gold, 25 + emberHeritageGold);
      final inv = container.read(inventoryProvider);
      expect(inv.countOf('slime_jelly'), emberHeritageMats['slime_jelly']);
      expect(inv.countOf('linen_scrap'), emberHeritageMats['linen_scrap']);
      expect(inv.countOf('charred_pelt'), emberHeritageMats['charred_pelt']);
      expect(inv.countOf('ashen_bark'), emberHeritageMats['ashen_bark']);
      expect(container.read(prestigeProvider).has(MetaPerk.emberHeritage), isTrue);
    });

    test('Ashen Swiftness and Soul Resonance apply to the combat sheet', () {
      final container = createContainer();
      final before = container.read(combatStatsProvider);
      container.read(prestigeProvider.notifier).awardSouls(40);
      container.read(prestigeProvider.notifier).buyPerk(MetaPerk.ashenSwiftness);
      container.read(prestigeProvider.notifier).buyPerk(MetaPerk.soulResonance);
      container.read(prestigeProvider.notifier).buyPerk(MetaPerk.fortunePilgrim);

      final after = container.read(combatStatsProvider);
      expect(after.attackSpeed, closeTo(before.attackSpeed * 1.10, 0.001));
      expect(after.xpGain, closeTo(before.xpGain * 1.25, 0.001));
      expect(after.lootFind, closeTo(before.lootFind * 1.15, 0.001));
      expect(container.read(prestigeProvider).travelSeconds, closeTo(1.0, 0.001));
    });

    test('meta upgrades persist across a save reload and a soft reset', () async {
      final container = createContainer();
      container.read(saveControllerProvider);
      container.read(prestigeProvider.notifier).awardSouls(20);
      container.read(prestigeProvider.notifier).buyPerk(MetaPerk.ashenSwiftness);
      container.read(playerProvider.notifier).recordKill();
      await container.read(prestigeProvider.notifier).executeAscension();
      await container.read(saveControllerProvider).flushNow();

      final blob = container.read(saveStoreProvider).load();
      expect(blob, isNotNull);
      expect((blob!['prestige'] as Map)['owned'], contains('ashenSwiftness'));
      expect(blob['achievements'], isNotNull);

      final reloaded = createContainer(save: blob);
      expect(reloaded.read(prestigeProvider).has(MetaPerk.ashenSwiftness), isTrue);
      expect(reloaded.read(achievementsProvider).lifetimePrestiges, 1);
    });

    test('full wipe clears Ash Souls and blessings', () async {
      final container = createContainer();
      container.read(saveControllerProvider);
      container.read(prestigeProvider.notifier).awardSouls(12);
      container.read(prestigeProvider.notifier).buyPerk(MetaPerk.emberHeritage);
      await container.read(resetGameProvider)();

      expect(container.read(prestigeProvider).ashSouls, 0);
      expect(container.read(prestigeProvider).owned, isEmpty);
      expect(container.read(achievementsProvider).lifetimePrestiges, 0);
    });
  });

  group('AchievementsNotifier', () {
    test('milestones grant one-time Ash Souls and stay unlocked', () {
      final container = createContainer();
      container.read(saveControllerProvider);
      final chronicle = container.read(achievementsProvider.notifier);
      for (var i = 0; i < 100; i++) {
        chronicle.recordKill(isBoss: false);
      }
      container.read(prestigeProvider.notifier).collectAchievementSouls();
      expect(container.read(achievementsProvider).isUnlocked('kills_100'), isTrue);
      expect(container.read(prestigeProvider).ashSouls, 2);

      for (var i = 0; i < 100; i++) {
        chronicle.recordKill(isBoss: false);
      }
      container.read(prestigeProvider.notifier).collectAchievementSouls();
      expect(container.read(prestigeProvider).ashSouls, 2);
    });

    test('boss and gold ledgers track across the current life', () {
      final container = createContainer();
      container.read(achievementsProvider.notifier).recordKill(isBoss: true);
      container.read(playerProvider.notifier).gainGold(250);
      expect(container.read(achievementsProvider).lifetimeBosses, 1);
      expect(container.read(achievementsProvider).lifetimeGold, 250);
    });
  });

  group('altar copy', () {
    test('EN and UK resolve perk names, titles, and currency', () {
      const en = L10n.english;
      const uk = L10n(AppLocale.uk);
      expect(en.t('ui.ashSouls'), 'Ash Souls');
      expect(uk.t('ui.ashSouls'), 'Душі Попелу');
      expect(en.t('ui.altarTitle'), 'Altar of Rebirth');
      expect(uk.t('ui.altarTitle'), 'Вівтар Відродження');
      expect(en.t('perk.emberHeritage'), 'Ember Heritage');
      expect(uk.t('perk.emberHeritage'), 'Спадщина Жарини');
      expect(en.t('perk.ashenSwiftness'), 'Ashen Swiftness');
      expect(uk.t('perk.fortunePilgrim'), 'Удача Паломника');
      expect(en.t('perk.soulResonanceDesc'), contains('25%'));
      expect(en.t('achieve.prestiges_1.title'), 'The Persistent');
      expect(uk.t('achieve.prestiges_1.title'), 'Невпинний');
      expect(en.t('achieve.prestiges_10.title'), 'Ashen Monarch');
      expect(uk.t('achieve.prestiges_10.title'), 'Попелястий Монарх');
      expect(en.t('ui.ascendConfirmBody'), contains('Ash Souls'));
      expect(uk.t('ui.ascendConfirmBody'), contains('Душі Попелу'));
    });
  });
}
