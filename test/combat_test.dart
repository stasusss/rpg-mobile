import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/data/enemies_data.dart';
import 'package:idle_rpg/models/combat_event.dart';
import 'package:idle_rpg/providers/combat_provider.dart';
import 'package:idle_rpg/providers/inventory_provider.dart';
import 'package:idle_rpg/providers/player_provider.dart';
import 'package:idle_rpg/providers/progress_provider.dart';
import 'package:idle_rpg/providers/settings_provider.dart';
import 'package:idle_rpg/providers/skills_provider.dart';
import 'package:idle_rpg/providers/stats_provider.dart';

import 'helpers.dart';

/// Runs the simulation for [seconds] of virtual time.
void runFor(FakeAsync async, ProviderContainer container, double seconds) {
  container.read(combatProvider);
  async.elapse(Duration(milliseconds: (seconds * 1000).round()));
}

void main() {
  group('combat loop', () {
    test('starts at full health and travelling', () {
      final container = createContainer();
      final state = container.read(combatProvider);

      expect(state.phase, CombatPhase.traveling);
      expect(state.playerHp, container.read(combatStatsProvider).maxHp);
      expect(state.enemy, isNull);
    });

    test('picks the next enemy from the current location and walks it in', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 0.1);

        final state = container.read(combatProvider);
        expect(state.enemy, isNotNull);
        expect(
          container.read(currentLocationProvider).enemyIds,
          contains(state.enemy!.def.id),
        );
        expect(state.phase, CombatPhase.traveling);
        expect(state.approach, greaterThan(0));
      });
    });

    test('engages once travel finishes', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, CombatNotifier.travelSeconds + 0.2);

        final state = container.read(combatProvider);
        expect(state.phase, CombatPhase.fighting);
        expect(state.approach, 0);
      });
    });

    test('damages the enemy and eventually kills it', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 30);

        expect(container.read(playerProvider).totalKills, greaterThan(0));
        expect(container.read(combatProvider).sessionKills, greaterThan(0));
      });
    });

    test('kills grant XP, gold and location progress', () {
      fakeAsync((async) {
        final container = createContainer();
        final goldBefore = container.read(playerProvider).gold;
        runFor(async, container, 30);

        final player = container.read(playerProvider);
        expect(player.gold, greaterThan(goldBefore));
        expect(player.xp + (player.level - 1) * 100, greaterThan(0));
        expect(
          container.read(progressProvider).killsIn('meadow'),
          player.totalKills,
        );
      });
    });

    test('loot lands in the bag and is recorded as discovered', () {
      fakeAsync((async) {
        final container = createContainer();
        // Auto-equip off so drops stay in the bag where we can count them.
        container.read(settingsProvider.notifier).toggleAutoEquip();
        runFor(async, container, 90);

        expect(container.read(progressProvider).discoveredItems, isNotEmpty);
        final materials = container.read(bagMaterialsProvider);
        expect(materials, isNotEmpty);
      });
    });

    test('emits damage events for the renderer', () {
      fakeAsync((async) {
        final container = createContainer();
        final bus = container.read(combatEventBusProvider);
        runFor(async, container, CombatNotifier.travelSeconds + 2);

        final events = bus.drain();
        expect(events, isNotEmpty);
        expect(events.map((e) => e.type), contains(CombatEventType.damage));
      });
    });

    test('pausing freezes the simulation', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 10);
        final killsBefore = container.read(playerProvider).totalKills;

        container.read(combatProvider.notifier).setPaused(true);
        async.elapse(const Duration(seconds: 30));

        expect(container.read(playerProvider).totalKills, killsBefore);
      });
    });

    test('a hopeless fight knocks the player down and then revives them', () {
      fakeAsync((async) {
        final container = createContainer();
        // Jump to the deadliest zone while still level 1.
        container.read(playerProvider.notifier).gainXp(2000000);
        for (final id in [
          'meadow',
          'goblin_woods',
          'howling_ridge',
          'skeleton_crypt',
          'spider_hollow',
          'orc_warcamp',
          'sunken_ruins',
        ]) {
          for (var i = 0; i < 60; i++) {
            container
                .read(progressProvider.notifier)
                .recordKill(enemyCatalog.keys.first);
          }
          container.read(progressProvider.notifier).travelTo(id);
        }
        container.read(progressProvider.notifier).travelTo('emberpeak');

        runFor(async, container, 120);
        expect(container.read(playerProvider).deaths, greaterThan(0));

        // A death in the last few seconds can land the snapshot mid-recovery.
        // The contract is that the downed window always ends.
        final downed = container.read(combatProvider);
        if (downed.phase == CombatPhase.playerDown) {
          runFor(
            async,
            container,
            downed.recoveryRemaining + CombatNotifier.tickSeconds * 2,
          );
        }
        expect(
          container.read(combatProvider).phase,
          isNot(CombatPhase.playerDown),
        );
      });
    });

    test('reviveNow restores full health immediately', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 5);

        final notifier = container.read(combatProvider.notifier);
        notifier.reviveNow();
        expect(
          container.read(combatProvider).playerHp,
          container.read(combatStatsProvider).maxHp,
        );
      });
    });

    test('a potion is refused when health is already full', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 0.2);

        final inventory = container.read(inventoryProvider.notifier);
        inventory.add('greater_potion', 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == 'greater_potion')
            .uid;

        expect(container.read(combatProvider).playerHp, greaterThan(0));
        expect(
          container.read(combatProvider).playerHp,
          container.read(combatStatsProvider).maxHp,
        );
        expect(container.read(combatProvider.notifier).usePotion(uid), isFalse);
        expect(container.read(inventoryProvider).countOf('greater_potion'), 1);
      });
    });

    test('drinking a potion heals and consumes one charge', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 12);

        final inventory = container.read(inventoryProvider.notifier);
        inventory.add('greater_potion', 1);
        final uid = container
            .read(inventoryProvider)
            .bag
            .firstWhere((e) => e.itemId == 'greater_potion')
            .uid;

        expect(container.read(combatProvider.notifier).usePotion(uid), isTrue);
        expect(container.read(inventoryProvider).countOf('greater_potion'), 0);
        expect(
          container.read(combatProvider).playerHp,
          container.read(combatStatsProvider).maxHp,
        );
      });
    });

    test('changing location restarts the approach with a local enemy', () {
      fakeAsync((async) {
        final container = createContainer();
        container.read(playerProvider.notifier).gainXp(100000);
        runFor(async, container, 20);

        for (var i = 0; i < 12; i++) {
          container.read(progressProvider.notifier).recordKill('green_slime');
        }
        container.read(progressProvider.notifier).travelTo('goblin_woods');
        async.elapse(const Duration(milliseconds: 100));

        final state = container.read(combatProvider);
        expect(
          container.read(currentLocationProvider).enemyIds,
          contains(state.enemy!.def.id),
        );
      });
    });

    test('an unlocked active spends mana and emits a skill event', () {
      fakeAsync((async) {
        final container = createContainer();
        final player = container.read(playerProvider.notifier);
        player.gainXp(100000);
        player.gainGold(200);
        final skills = container.read(skillsProvider.notifier);
        expect(skills.learn('arcane_spark'), isTrue);
        expect(skills.learn('mana_well'), isTrue);
        expect(skills.learn('mana_bolt'), isTrue);
        expect(container.read(unlockedActivesProvider), isNotEmpty);

        final bus = container.read(combatEventBusProvider);
        runFor(async, container, CombatNotifier.travelSeconds + 8);

        expect(bus.drain().map((e) => e.type), contains(CombatEventType.skill));
      });
    });

    test('the activity feed stays bounded', () {
      fakeAsync((async) {
        final container = createContainer();
        runFor(async, container, 400);

        expect(
          container.read(combatProvider).feed.length,
          lessThanOrEqualTo(CombatNotifier.feedLimit),
        );
      });
    });
  });
}
